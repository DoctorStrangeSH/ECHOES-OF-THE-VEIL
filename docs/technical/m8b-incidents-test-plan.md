# M8b test plan: world incidents

Automated (CI):
- `test_incidents_depend_on_the_ending`: nothing before the ending; names/seal/patrol only under open record/custodians/accord; town incidents always.
- `test_incident_lifecycle_and_consequence`: one at a time, clearing moves to report, the reporting dialogue pays and closes it, 2-day cooldown, the next starts at dawn, ignoring it fails it after 3 days with a relationship cost and a flag.
- `test_incident_npcs_can_be_found_after_the_ending`: every reporting NPC is somewhere at noon.
- Validator: incident scenes allow combat, echoes are not in walls, cases are clear → report, a dialogue entry handles every report stage.
- Smoke: the morning after the ending Lantern Row acts up; its three echoes are cleared and Mara closes the case.
