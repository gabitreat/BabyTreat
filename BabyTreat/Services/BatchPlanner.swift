import Foundation
import SwiftData

/// Creating, and throwing away, a cooked batch.
///
/// A batch is not a special kind of meal. Cooking once for two days still puts a
/// normal `MenuEntry` on **each** day — which is what makes the rotation meter
/// count carrot twice for a Monday-and-Tuesday batch. Counting it once would let
/// repeat batching quietly narrow the diet while the meter said everything was
/// fine.
@MainActor
enum BatchPlanner {

    struct Plan {
        let batch: SoupBatch
        let entries: [MenuEntry]
    }

    /// Builds a batch and its per-day menu entries. Does not insert them.
    ///
    /// `spanDays` is clamped to what the recipe's nitrate load allows, so a
    /// caller cannot create a two-day spinach batch by passing 2.
    static func makePlan(
        recipe: Recipe,
        startDate: Date,
        spanDays: Int,
        cookedAt: Date,
        slot: MealSlot = .dinner,
        foodsByID: [String: Food]
    ) -> Plan {
        let risk = recipe.nitrateRisk(foodsByID: foodsByID)
        let allowed = min(max(spanDays, 1), BatchSafety.maxSpanDays(risk: risk))

        let batch = SoupBatch(
            recipeID: recipe.id,
            cookedAt: cookedAt,
            spanDays: allowed,
            startDate: startDate
        )
        batch.applyDefaultStorage()

        // Only base ingredients reach rotation. Accents ride along in the dish
        // but must not fill a rotation slot.
        let baseIDs = recipe.foodIDs.filter { foodsByID[$0]?.role.consumesRotationSlot ?? true }

        let entries = batch.coveredDays.map { day in
            let entry = MenuEntry(
                date: day,
                slot: slot,
                dish: recipe.title,
                foodIDs: baseIDs,
                recipeID: recipe.id,
                calendar: MealRules.calendar
            )
            entry.batchID = batch.id
            return entry
        }

        return Plan(batch: batch, entries: entries)
    }

    /// Creates the batch, replacing whatever was planned in those slots.
    @discardableResult
    static func create(
        recipe: Recipe,
        startDate: Date,
        spanDays: Int,
        cookedAt: Date,
        slot: MealSlot = .dinner,
        in context: ModelContext
    ) -> SoupBatch {
        let foods = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        let byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let plan = makePlan(recipe: recipe, startDate: startDate, spanDays: spanDays,
                            cookedAt: cookedAt, slot: slot, foodsByID: byID)

        // Clear any existing plan for the days this batch takes over.
        let existing = (try? context.fetch(FetchDescriptor<MenuEntry>())) ?? []
        for entry in existing where entry.slot == slot && plan.batch.covers(entry.date) {
            context.delete(entry)
        }

        context.insert(plan.batch)
        plan.entries.forEach { context.insert($0) }
        try? context.save()
        return plan.batch
    }

    /// Marks a batch thrown out.
    ///
    /// Voids the planned meals it left behind, but never touches a meal already
    /// logged — that food was eaten, and the journal records what happened.
    static func discard(_ batch: SoupBatch, at date: Date = .now, in context: ModelContext) {
        batch.discardedAt = date

        let logs = (try? context.fetch(FetchDescriptor<MealLog>())) ?? []
        let loggedDays = Set(logs.filter { $0.batchID == batch.id }.map { SoupBatch.dayKey($0.date) })

        let entries = (try? context.fetch(FetchDescriptor<MenuEntry>())) ?? []
        for entry in entries where entry.batchID == batch.id {
            guard !loggedDays.contains(SoupBatch.dayKey(entry.date)) else { continue }
            context.delete(entry)
        }
        try? context.save()
    }

    /// The batch covering a day's slot, if there is one.
    static func batch(covering day: Date, batches: [SoupBatch]) -> SoupBatch? {
        batches.first { !$0.isDiscarded && $0.covers(day) }
    }
}
