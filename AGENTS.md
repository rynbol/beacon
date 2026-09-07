# Beacon project direction

- The user's goal is a personal recreation of Unforgetful, the subscription reminder app named in DESIGN.md. Prioritize its documented behavior and the user's preferred interface over inventing a different productivity product.
- Mac first. The user said design was the primary problem with the old implementation.
- Do not continuously inspect, capture, activate, or watch the user's app. Use UI access only for a specific edit or purposeful test, and stop as soon as that check is complete. Prefer source inspection and automated checks for routine work.
- Keep Apple Reminders as the source of truth and preserve existing reminders. Use isolated sample data for UI write tests.
- Separate documented reference features, implemented behavior, and device-verified behavior. Passing planner tests is not proof of end-to-end notification delivery.
