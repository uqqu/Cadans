[🇬🇧 English](README.md) • [🇷🇺 Русский](README.ru.md)

<p align="center">
<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/demo.gif">
</p>

##

Welcome to **Cadans** – an input customization tool that lets you assign actions to keys, combinations, and gestures.  
Simple taps, holds, chords, modifiers, and multi-zone mouse gestures can all be combined and used in the way that suits your workflow.  

Any event can trigger actions – from inserting text or symbols to controlling the system or running custom logic.  
Each event also comes with its own fine-tuning options and can be chained together to form sequences with intermediate and final actions.  

Cadans works with any keyboard and mouse, treating them as a unified input system – no firmware or special hardware required.  
Assignments can be defined per application and per keyboard layout, organized for different workflows, and switched on the fly.  

Only what you assign is affected – everything else stays unchanged, and input remains native unless explicitly overridden.  

You can use just one part of it – for example, gestures only, or a single key for custom functions in a specific app.  
Or go deeper and build more complex logic – it’s entirely up to you.  
<br>

# 🚀 Events

> All animations and their frames are slowed down for clarity

### > Taps and holds

Basic events: one key – two actions.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/taphold.gif" width="400">


The hold trigger timing can be configured globally or set individually for each key.  

Tap/hold handling does not delay input. Events trigger on timer, on key release, or on subsequent input:  
- the base input is sent immediately on key release (0.04–0.08s – typical keydown–keyup timing during typing);  
- hold actions trigger as soon as the timer expires (as configured; typically 0.1–0.15s), regardless of how long the key continues to be held.  

> This only applies if a hold action is defined.  
> Otherwise, no extra checks are performed and the key behaves according to its tap assignment or just natively:

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/unassigned.gif" width="400">

##

### > Chords / combos

The next event type is chords. Simple: press the assigned combination – the event triggers.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/chords.gif" width="400">

Each key can participate in any number of chords.  
To resolve overlaps (`1+2` and `1+2+3`) and to prevent accidental triggers, an optional chord confirmation can be enabled, as in the example above.  

It follows the same hold logic: the chord is only accepted after a short hold.  
If the combination breaks during that time, it won’t trigger.  
If no confirmation time is set, the chord triggers immediately when the combination is matched.

##

### > Gestures

Any key can act as a trigger for another type of event – gestures.  
If gestures are assigned to a key, it automatically becomes a trigger without restricting other assignments.  

When held, it enters drawing mode: mouse movement leaves a trail, and upon release, the drawn shape is matched with the assigned gestures.  
If a match is found, the gesture event is triggered.  

If no movement occurs, the key behaves as if no gestures were assigned at all – as a tap, with hold branching, as part of a chord, as a modifier, or according to its default system behavior.  
The same applies if no gesture is recognized.  

Gestures are divided into 9 zones – 4 along the screen edges, 4 corner zones, and one central zone – based on where the drawing starts.  
This zoning can be adjusted or completely disabled in the settings.

Gestures for each zone are defined independently. When determining whether to activate gesture drawing, only gestures from the current zone (based on cursor position) are considered.  
If no gestures are defined for that zone, gesture drawing does not activate, and the key behaves according to its other assignments or system defaults.

The example below demonstrates zone-specific assignments – gestures are assigned to RMB in all zones except the center.  
As a result, behavior in the center remains system-default, while outside of it, 8 independent gesture groups become available:

https://github.com/user-attachments/assets/1d3c148d-8408-46f2-87c9-88a7a4533e1c

> This example is part of the default preset, which you can use as-is or customize  

##

Also, each gesture has its own recognition options:
- rotation invariance;
- direction invariance (including reverse);
- sensitivity to the original gesture size;
- for closed shapes: starting-point independence along the path.

These options can be combined within a single gesture or across multiple gestures.  

Trigger keys also include visual settings for gestures: line color, gradient length and cycling, hint text position and its visibility during drawing.  

https://github.com/user-attachments/assets/1559d7d0-45ea-4503-865a-50629ccd3015

##

### > Custom modifiers

The last type of assignment is a modifier. It allows you to define new actions for **all** other events when they are used together with it.  
`q (hold) → ~`  
`[mod_1] + q → °`  
`[mod_1] + q (hold) → ¬`  

A modifier is a unique type of hold assignment and does not affect the tap behavior or assigned gestures of the same key.  
It applies instantly, without waiting for the hold threshold. The threshold only determines whether the key is treated as a tap:  
if the key is released quickly – it is treated as a tap; if held – the tap action is ignored (an attempt to use it as a modifier).  
If the modifier is used in at least one event, the key’s tap action will no longer trigger – regardless of the hold threshold.  

> This is the only assignment type that can be applied to system modifier keys.  
> This ensures full compatibility with standard system shortcuts. The program only intercepts combinations that you explicitly assign.  

For example, if you define `Alt[mod_1]+F4 → (some_action)`, it will override the system behavior and execute your custom action, while other combinations without explicit assignments will continue to work as usual – `Alt+Tab`, `Alt+Esc`, ….  

Modifiers can be combined with each other to create new assignments – `Alt[mod_1] + q → §`, `RMB[mod_2] + Alt[mod_1] + q → ∑`, in any combination you define.

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/modifiers.gif" width="400">

##

### > Event sources

In addition to the keyboard (including extra key rows), **mouse** events are supported on the same terms and with the same capabilities.  
They can also be part of chords, act as modifiers, have their own actions, holds, gestures, and transitions. They are not treated as a separate subsystem and can be used in the same way as keyboard events.  

There are only 3 exceptions:
- mouse scroll events and additional key rows do not support hold actions by their nature, so hold assignments cannot be defined for them;
- for safety reasons, basic mouse button presses cannot be assigned at the **root** level **without** modifiers (gestures are still allowed);
- for the same reason, system modifier keys can only be assigned as hold-based modifiers, without a tap action, in all cases.

Everything else is available without restrictions, in any combination, and with no hardware requirements.  
<br>

# 🗂️ Grouping and scope of assignments

### > Layers

All assignments are stored in separate files – layers, which can be configured independently and used to group assignments by categories and usage scenarios.  

Each layer’s active state can be toggled at any time, either through the interface or via assignments.  

Each active layer has its own priority, which is used to resolve conflicts between overlapping assignments for the same events.  

Switching layers or sets of layers can be part of your regular workflow:  
`\+1 → Toggle navigation layer`  
`\+2 → Disable all layers except *n*`  
`\+3 → Enable layer set *abc*`

##

### > Layouts

Assignments you add to a layer are global by default – they work as long as the layer is active, without additional conditions.  
However, you can extend this behavior by adding assignments for specific keyboard layouts – they only apply to those layouts.  
On each layer, you can define assignments for different layouts, and they always take priority over that layer’s global assignments.

For example, you can define a global assignment `Alt+o → ø`, and on the same layer add a layout-specific one – `Alt+o → ö`.  
This way, the event in the specified layout will have its own action, while all others will use the global one.  

You can also omit the global assignment entirely – in that case, the event will not be handled by the program on other layouts, and the default system behavior will remain.  

The number of layouts and assignments is not limited.  

[ru] `o (hold) → «`, `. (hold) → »`  
[en] `o (hold) → “`, `. (hold) → ”`  
[de] `o (hold) → „`, `. (hold) → “`  

> You can redirect assignments from one layout to another in the settings (`User` → `Layout aliases`).  
> This is useful if you use a non-standard keyboard layout, such as Colemak, but want to always use assignments created for qwerty, since assignments are bound to physical keys (scancodes), not to the characters they produce.

##

### > Processes

You can also set a process rule for each layer. A layer’s assignments can be excluded from certain applications, or limited to a specific process or group of processes.

This allows you to fine-tune the behavior of each event depending on the active process and layout – without having to think about it during use.  

Layers without process rules apply everywhere.  
To exclude a process or group, use `-app.exe`. There is no need to explicitly specify that the layer should be active for all other processes.  
To restrict a layer to specific processes, use `+app.exe, app_2.exe`.  

For convenience, processes can be grouped in the settings – `browsers=firefox.exe, chrome.exe, edge.exe, …`.  
These group names can be used in rules, including with additional refinements – `-browsers, +firefox.exe`.  
Updating a group in the settings automatically affects all layers where it is used.  

##

### > Assignment tree

All assignments are combined into a single tree based on the logic described above.  
For each active layer, layout, and process context, the final assignments are resolved with all priorities taken into account.

During runtime, the system simply moves through this prebuilt tree, where all of this logic is already resolved...  

### _“What tree”? Oh, right:_  
<br>

# 🔗 Event chains / sequences

Each assignment is not just an action – it also contains a nested table of assignments: keys, chords, and gestures. This table is structured the same way as the root level, but with its own assignment possibilities.

If no children are defined and the nested table remains empty, the assignment is considered final, and the behavior reduces to a simple `event = action`, without additional logic.  

If children are present, triggering the event transitions into its assignment table and continues along the chain until a final node is reached or the chain is interrupted.

An interruption occurs in two cases:
- if no new events happen within the waiting time (300 ms by default);
- if a new event cannot continue or complete the chain.

On interruption, the current assignment’s action is executed, and the system returns to the root level.  
If the interruption was caused by a new event with no matching assignment, it will be processed from the root after returning.

> This is the default behavior – but importantly, **all** of it can be customized to fit **any** use case.  

All chain logic and transitions are handled by the system – you don’t need to explicitly control when a chain resets, which action is final, or which one should start a new chain.  
You simply continue your input, and all transitions and interruptions are handled automatically according to the assignments you defined.

<details><summary>Detailed: how chain interruption works</summary>

This slowed-down example demonstrates two simple chains – `a, e → æ` and `n, ~ → ñ`, with no additional assignments.

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/chain_interruptions_detailed.gif" width="400">

Take a look at the sequence `a, n, ~`:
- `a` starts a chain – the system begins waiting for the next event;
- `n` interrupts it, since there is no assignment for `a, n`;
- …due to the interruption, the action of `a` is executed, and after returning to root, the system **immediately** starts a new chain from `n`;
- the final `~` completes the chain from `n`, triggering `ñ`, and the system returns to root again.  

No explicit reset actions were performed.  
No special handling was defined to execute the base `a`.  
No manual transition to a new chain was needed, even though `n` occurred during the previous one.  

We simply typed three characters, leaving all chain logic and transitions to the system.</details>

##

And of course, chains can use all types of events – from taps and holds to chords and gestures from different zones.  
The example below shows simple hold-based branching with control actions: two keys, two levels, one branch – up to 16 possible actions.

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/chains.gif" width="400">


There are no depth limits for chains – from something like Morse code to full word autocorrection, anything you can come up with.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/morse.gif" width="400">

Chains can consist of any event types, including chains made up entirely of chords or gestures.

https://github.com/user-attachments/assets/c8595311-d7a6-46d7-a846-d1d9c4055fa7

> The only type that does not have its own transition is the modifier.  
> It plays the same logical role – opening new assignment fields – but within the current level.  
> And those assignments can introduce further transitions.

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/chain_with_chords.gif" width="400">

##

Even in this basic form, chains can already be considered an _advanced feature_.  
In practice, the vast majority of your assignments will likely be simple and standalone, without complex logic.  
But when needed – anything is possible.  

Each element in a chain can be configured in detail:
- waiting time for the next event;
- return-to-root behavior;
- 5 child-event behavior modes;
- intermediate action execution without breaking the chain.

Any behavior can be implemented.  
The example below shows a simple tap-based chain where all intermediate elements are executed (native behavior), along with an additional final action.  
A slightly playful example – but fully functional:  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/chain_instant.gif" width="400">


> Each level of each chain is defined independently, and the same key can act differently at different levels – as a modifier, part of a chord, a simple tap, a gesture trigger, or a node with further transitions.  
> Each new level is a new, clean assignment space.  
>  
> `\[modifier]+e, \[tap], \[hold], chord[\+z+x], \+[gesture] → ƒ Start pomodoro timer`

##

Technical notes:

- Pressing `modifiers` and `chord keys` at non-root levels already pauses the interruption timer, even if the combination is not yet complete. In this case, the interruption will occur on key release.
- At runtime, when transitioning with a held `modifier`, if that key also has an assignment of the same type on the next level (even with a different value), its value is updated accordingly without requiring it to be released and pressed again:  
  - for example, `Alt[mod_1]+q, Alt[mod_2]+w → (some_action)` – if `Alt` is held through the transition, it acts as `1` on the first level and automatically becomes `2` on the next;
  - if no modifier assignment exists for the held key after the transition, it is reset and will not trigger any action on release;
- When building the structure for UI and runtime, child elements of identical assignments across layers are merged.  
For different assignments, the higher-priority one is selected, and only its children are used.
<br>

# 🧠 Assignments and actions

When creating assignments for events, a number of fields and options are available:  


### > Action

Defines what will be executed when this assignment is reached.  
If the assignment is an intermediate element in a chain, the action is executed on interruption or when explicitly specified.  

Actions can include:
- inserting a single character or full text (from a work email to a cherry pie recipe);
- simulating key presses;
- calling a function;
- for hold events, a special type `modifier` is also available.  

> There are also `disabled` and `default` types.
> These are useful in chains when you don’t need a custom action on interruption, but instead want either the key’s default behavior or no action at all.  
> When creating a new chain, intermediate elements without explicit assignments are automatically set to `default` for tap events, and `disabled` for holds.

##

The `key simulation` type accepts a string in [AHK format](https://www.autohotkey.com/docs/v2/KeyList.htm), for example:  
`{SC010}`, `+^{Left}`, `{End}{Shift down}{Home}{Shift up}{Backspace}`.  

##

When selecting the `function` type, an additional window opens with a set of predefined functions that can be used as-is – from simple everyday actions like “increment number under cursor”, “insert current date in format …”, “start auto-scroll”, or “stop music after a timer”, to external API calls such as “explain selected term from Wikipedia” or “weather forecast for city N”.  

There are also several functions for managing layers directly through assignments.  

You can define your own functions and call them directly as `function(parameters)` – no need to add them to the predefined list.

> String values for functions should be written *without* quotes, for example: `ExchRates(USD, RUB)`.  
> Characters like `,` and `[` in string values must be escaped with `\`.  
> For functions without parameters (or when using default function behavior), parentheses can be omitted, leaving just the function name – for example: `AutoScrollStart`.  

##

For the `modifier` type, you need to specify a number from `1` to `60`.  
The same modifier value can be assigned to different keys – they will all map to the same set of assignments.  

##

The `chord part` type cannot be set or removed manually.  
It is assigned automatically to hold events (**and may override an existing assignment**) for all involved keys when creating chords, and is removed automatically when chords are deleted.  

##

“Gesture trigger” is not a separate type – it can work together with any other assignment, or without one at all.  

##

### > Action on release

Located in a separate section. This action is triggered when the key is released.  

It can be used as an additional action or as part of more advanced logic.  
In terms of types and values, it works the same way as the main action.  

Like all assignment parameters, it belongs to the specific event it is defined for:  
**Release after a tap and release after a hold are two different cases** – only one of them will be triggered.  

##

### > Time before hold activation

A field where you can specify a custom delay before the hold event is triggered.  
If not set, the global value from settings is used.  

It is defined in the **tap** assignment and determines when it expires. It can also be specified in the hold assignment, but it will still be saved for the “base” event.  

If there is no corresponding hold assignment, this setting has no effect.  

> Special case for chords:  
> If a hold threshold is specified, it is used as a confirmation time to prevent accidental triggers and resolve overlapping chords.  
> If not set, the chord event is triggered immediately when the keys match.

##

<details><summary>Chain settings (advanced)</summary>

### > In-chain behavior

For assignments used as part of a chain, two additional options are available:

- `instant` – the assignment’s action is executed immediately when the event is accepted, rather than on interruption.  
  The chain itself is not broken and can continue normally.  

  This option is used in the “playful” example from the chains section, where typing `d, a, m, n` triggers the final action on release (shows tooltip) while still producing all intermediate characters.  

  This option is configured per assignment.  

- `irrevocable` – prevents returning to the root level from this assignment, whether due to interruption or after reaching it as a final element.  
  Returning is still possible via other events (unless they are also marked as `irrevocable`).   

  This allows you to enter a deeper level once, perform multiple actions there, and only then return.  

  **Be careful not to lock yourself into a level.**  

##

### > Child assignment behavior

The most basic parameter – the _waiting time for a child event_.  
If no child event occurs within this time, the chain is interrupted.  

The result of the interruption (executing the action and returning to root) depends on the options described above.  
As with the hold threshold, if not specified explicitly, the global value from settings is used (300 ms by default).


The _“behavior for unassigned child events”_ option allows you to control what happens when a chain is interrupted by an event that has no assignment.  

By default, this is: _“execute the current action and return to root”_, after which the triggering event is processed from the root level.  

Alternative behaviors include:
- returning to the previous level instead of the root (search for assignment at the previous level);
- the same options without executing the current action;
- ignoring unassigned events entirely.  

> Ignoring events can be useful to filter out accidental inputs in longer chains.  
> However, when combined with `irrevocable`, it can completely lock you into a level.  
> Be careful with this combination, and **always** ensure there is a way to return to the root.  
> The interface will also request confirmation if you try to add an assignment with a similar combination.</details>

##

### > Gesture overlay settings

A cosmetic section, used when a key acts as a gesture trigger.  
Here you can configure the position of the hint text and separately customize three types of zones – corner, edge, and center/general zone.  

Each type of zone can have its own line color or color sequence, or a special value `random(n)`, which will pick a random color for each new gesture.  

If multiple colors are specified, or `random` with `n > 1` is used, you can also define the `gradient length` and whether it should be `cyclic`.  

##

### > Name in GUI

And the simplest option – how this assignment appears in the interface.  

If left empty, the action text will be shown.  
There are no hidden behaviors here – this is simply a way to improve readability, especially for more complex actions such as functions.  

For gestures, this field cannot be empty. If not specified, the action text will be used automatically.

---

https://github.com/user-attachments/assets/d0ebd374-b51b-4404-94bf-0b4216ec0f7c

<br>

# 🖥️ GUI

> All GUI elements have tooltips that appear when hovering while holding `Alt`.  
> If any tooltip feels unclear or incomplete, please [report it](https://github.com/uqqu/Cadans/issues).


GUI view with almost all built-in layers enabled:

<p align="center">
<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/gui_enabled_layers.png">
</p>

> The modified layout shown in the screenshot is not remapping – it is simply a [different keyboard layout](https://github.com/uqqu/qPhyx_layout).

##

### > Keyboard view

The main part of the interface is a keyboard view, with additional mouse buttons placed around the numpad, and a helper key showing the current modifier(-s) state.  

Each key displays all active assignments for tap events (top part of the key) and hold events (bottom part, if assigned), based on the current chain path.  

The outline color of a key indicates the assignment type.  
Additional markers show locally overridden settings, and counters in the corners indicate the number of child assignments (top for tap events, bottom for hold).  
All colors can be configured in the settings.  

If an event has multiple overlapping assignments across layers, only the highest-priority one is shown – exactly as it will be used at runtime.  

> Note: the interface shows global and layout-specific assignments separately, while runtime behavior is based on their merged result (with layout-specific assignments taking priority).

`LMB` and `RMB` on keys navigate through tap and hold events respectively.  
Basic navigation is also available using physical keyboard taps/holds.  

For modifiers, which do not have their own transition by design, `RMB`/hold toggles the modifier state itself, immediately affecting other assignments.  

Due to system limitations, keys without hold events cannot be navigated via hold; and system modifiers do not have a press transition – their modifier assignment form opens immediately instead.  

The special `Mod` key acts as an indicator of the current active modifier set, based on the internal representation `sum(modifier_value²)`.  
Pressing it resets all active modifiers.  
Active modifier values are shown individually in the top path bar and are also indicated by distinct outline colors on the corresponding modifier keys.  

Additional key rows (F13-24 keys and multimedia/office keys) can be enabled in the settings.

##

### > Transition path and adding assignments

<p align="center">
<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/gui_path.png">
</p>

At the top, the current chain / transition path is displayed.  
All levels are clickable – you can return to any of them (preserving the modifier state of that transition).

The transition event and modifier value (if present) are shown between levels:  
`➤` for taps, `▲` for holds, `▼` for chords, and `•` for gestures.

Assignments are added to the event at the current path.  
So, to add an assignment for `q` (more precisely, `sc016`), navigate to that event and use the buttons in the top-right corner to open the assignment creation/edit form.

The text next to the assignment buttons indicates the current action type with a single letter.  
The buttons themselves include indicators and counters, just like on the central view.  
Next to them are buttons for resetting the current assignment and all of its children.

> Transitions via taps and holds always display assignment buttons for both “base” events, so for simple assignments it does not matter which event was used to enter the level.
> However, all child assignments are shown and added strictly according to the current path.

Clicking an assignment button opens a form with all parameters from the previous section.

If the assignment is edited outside of a single-layer view, a dropdown appears at the top of the form to select the layer the assignment will be added to.

##

### > Layouts

Below the keyboard view, on the right side next to the settings button, there is a dropdown for switching layouts.  

In the interface, global and layout-specific assignments are shown **separately**, while at runtime they are merged – with layout-specific ones taking priority.  

All navigation and assignment creation happen for the layout currently selected in the list.  

Holding `Alt` on this dropdown list shows which layouts have child assignments at the current path.  

> If a layer appears empty where assignments are expected, check other layouts.

The layout list always includes global assignments, layouts installed in your system, and (if the corresponding option is enabled) layouts not present in the system but used in layers.  

##

### > Processes

The left dropdown, under the “arrows”, is used to select the process context.  

If process rules are set on active layers, the list will include, in addition to the general context `*`, separate contexts derived from those rules.

A context is a runtime grouping of processes that end up using the same execution branches. It does not always directly correspond to process rules (this is expected).  

Selecting an item in this menu shows which assignments are applied for that context at runtime.  

In single-layer view/edit mode, this menu is disabled and simply displays the layer’s process rule in its raw form.  

When a non-global context is selected, holding `Alt` shows which layers contributed to this context and all processes included in it, without grouping.

##

### > Additional interface details (optional)

The list panels are fairly self-explanatory, so feel free to explore them directly.  
> tldr: Double-clicking on an item navigates to it; pressing `Alt` still displays tooltips.  
More detailed descriptions are included below if needed.

<details><summary>Bottom lists (chords, gestures, layers)</summary>

### > Chords

The bottom-right list shows chords assigned at the current path. Clicking any of them will also highlight the corresponding keys on the keyboard view.  

Along with the key/button combination and assigned action, the list also shows the number of child assignments (if any), as well as the layers the chord is defined on.  

To add a new chord, click the corresponding button, select the desired combination in the interface or on your keyboard/mouse, and press `Save` to proceed to assignment setup.  

For chords, the hold time parameter defines the “confirmation” delay before the event is accepted.

To navigate into a chord and view or add child assignments, double-click it in the list.  

##

### > Gestures

The bottom-center list shows gestures assigned at the current path. The last event in the current path acts as the “trigger”.  
Gestures cannot be added at the root level, under chords, or directly under other gestures – in these cases, there is no trigger.  

> Gestures are tied to the `tap` event, as drawing mode starts immediately on key press.  
> When navigating via `hold`, gestures are still shown in the list and can be modified, but this is simply the same list as for the `tap` transition.  
> The same applies to the `hold threshold` and `gesture overlay` settings if the forms – they belong to the `tap` assignment, but are also accessible via `hold`.

At levels where gestures cannot be added, the list shows trigger keys (if any), along with their modifiers and the number of gestures assigned to them.  

At other levels, only the gestures themselves are shown, along with:
- a short zone label;
- custom recognition options;
- number of child assignments;
- the layer the gesture is defined on.  

Holding `Alt` allows you to inspect all gesture parameters (non-default ones are marked with `>`), including inherited color from the parent.  

##

The buttons below the list allow you to preview the “reference” gesture or modify the assignment. Redrawing the gesture is not required when editing.  

When previewing, the gesture is displayed in the zone it was assigned to. The parent color is also applied.  

For gestures with the `bidirectional` and/or `any start point` options, the preview reflects these behaviors by choosing a random direction or position.  
If `scale impact` is non-zero, the gesture is shown at its original size; otherwise, it is displayed in a normalized (scaled-down) form.  

When editing an assignment, additional recognition options can be configured.  

The `any start point` option is only available for closed gestures (distance between the first and last points < 10% of total length).  
When enabled, the gesture is automatically smoothed to a unified start and end point.  

##

### > Layers

<p align="center">
<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/gui_layers.png" width="600">
</p>

The bottom-left list shows all layers. Technically, these are files and subfolders inside the `layers` directory, preserving the same structure.  

The checkbox toggles layer activity (`RMB` – enable with highest priority). Active layers display their relative priority.  
The `increase/decrease priority` buttons also support `RMB` – the layer is moved directly to the top or bottom.  

At the root level, the number of assignments for the current and other layouts is also shown for each layer (treating “global” individually).  
At other levels, assignments at the current path and the number of child assignments for base events are displayed – separately for each layer.  

Folders always show the number of nested layers.  

##

Above the list is a tag menu that lets you filter layers by their assigned tags.  
This is purely a visual feature – it does not affect layer activity.  
Selected tags are preserved between sessions.  

##

The `Meta` button allows you to edit the layer name (and path), its description (with `Alt`), tags, and most importantly – the layer’s process rule.  

The rule applies to the entire layer:
- to enable the layer only in specific processes – `+app.exe`;
- to enable it everywhere except specified ones – `-app.exe, app2.exe`.  

You can use group names from settings (changes to a group do not require updating layer rules that reference it), and extend them directly in the rule – `-browsers, +firefox.exe`.  
Rules take effect immediately after saving.  

##

Double-clicking a layer switches to a separate view/edit mode.  

In this mode, assignments shown on the layout are taken only from the current layer – regardless of other layers’ activity.  
When adding or editing assignments, the form does not include a layer selection – the current layer is implied.  
The `root` level in the path is replaced with the layer name.  

You can return to the full active-layer view using the corresponding button below the list.  

##

The program includes several predefined layers that you can enable and test immediately  
(in another window – the interface intercepts events for transitions and other purposes).  

From typographic and language-specific symbols to gestures, an emoji keyboard, temporary keyboard layouts, control actions, and functions. There are also a couple of playful ones.  

If something catches your interest – use it as a starting point and adapt it to your needs.  
Or maybe you’ll create your own useful layer and want to share it?  

##

<details><summary>JSON Layer Format</summary>
<br>

> You don’t need to edit JSON directly – everything is available through the GUI.  
> This section is here for reference, if you’re curious how things work under the hood.

Each file represents a single layer and contains assignments grouped by layouts.

File structure:

> Values in square brackets indicate defaults.

```jsonc
// meta information: version, tags, description, process rule
{
  "<LAYOUT_ID>": [  // "0" – global assignments
    "gesture_options",  // string (color settings for child gestures)
    {  // scancode table
      "<scancode>": {
        "<modifier>": [
          "action_type",               // int (1-7)
          "value",                     // string
          "up_action_type",            // int (1-7) [1 – disabled]
          "up_value",                  // string [""]
          "is_instant",                // bool [false]
          "is_irrevocable",            // bool [false]
          "custom_long_press_time",    // int [0]
          "custom_next_key_time",      // int [0]
          "unassigned_child_behavior", // int (1-5) [4]
          "gui_shortname",             // string [""]
          "<nested>"  // gesture_options, scancodes{}, chords{}, gestures{}
        ],
        "<modifier + 1>": [  // assignment for hold event
          // ...
        ],
      },
    },
    {  // chord table
      "<chord_scancodes>": {
        "<modifier>": [
          // …same structure
        ],
      },
    },
    {  // gesture table
      "<pool+vectors>": {
        "<modifier>": [
          // …same structure
          // gesture_options here contains recognition settings
        ],
      },
    }
  ],
}
```
##
</details>
</details>

Assignment swapping is optional and not required for getting started – you can come back to it later.

<details><summary>Moving assignments</summary>

### > Assignment swapping

The first button to the right of the process selector switches the interface into swap mode `🔀`. In this mode, navigation and modifier toggling are disabled.  

You can swap assignments by dragging with the mouse or by pressing two physical keys sequentially. The swap includes all child events.  

> Only assignments inside the program are affected – the system layout remains unchanged.  
> Therefore, if you swap two keys with the `{Default}` action type, their visible “action” will not change. The swap still occurs – both keys simply continue to display their base value according to the layout.  

After making changes, you can save them.  
By default, only the swaps visible in the current view are saved – without applying them to other layouts or assignments hidden under modifiers.  

If you need a more global swap, open the dropdown next to the `Save` button and choose the appropriate option.  

Swaps are applied to all active layers.  
In single-layer view/edit mode, they apply only to that layer.  

##

While dragging an assignment button, all incompatible swap targets, according to constraints, are disabled.  

For example:
- a key with a tap or hold assignment, except a modifier, cannot be swapped with system modifier keys;
- a key with a hold assignment cannot be swapped with keys that do not support that event.

##

### > Copying and pasting assignments

The three buttons next to swap mode control the assignment clipboard. It is available only in layer edit mode.  

In the copy menu (`⧉`) three options are available:
- copy current view – only the currently visible assignments – **child assignments for the current path and modifier**;
- copy entire level – the current **tap** assignment and all its child assignments across **all modifiers** at the current path;
- copy extended level – everything from the previous option **+ the same for hold**.  

At the root level, the third option is unavailable (there is no “paired” event), and copying the entire level ignores the tap assignment (as it does not exist there).  

##

The copied view or level is placed into the clipboard, which can be opened via `👁`.  

In clipboard view mode, assignments cannot be added or edited, but they can be **swapped**.  

If an “extended level” was copied, switching between base events in the view is done via a dedicated button next to their assignments.  

##

If the clipboard contains assignments, the paste menu `📋` becomes available in layer edit mode.  

Three paste options are available:
- append – add only assignments from the clipboard that are not present in the current view;
- merge – paste all assignments from the clipboard, replacing conflicting;
- replace – completely clear the current view and insert all assignments from the clipboard, even if there are no conflicts.  

In all cases, the clipboard is preserved and updated:
- append – the clipboard retains only assignments that were not inserted (if all are inserted, it becomes empty);
- merge – all replaced assignments are moved into the clipboard;
- replace – the entire removed view is moved into the clipboard.  


> Paste ignores active modifiers in the current view – assignments are applied only to the current path.  ; TODO

</details>

##

### > Settings

Finally, you can configure global behavior and interface preferences in the settings `🔧`.

Here you can adjust everything from tap/hold timing and child-event timeouts to gesture colors and visual appearance.  

Also check what the indicator and outline colors represent, and change them if needed (the `Colors` tab).  

Before creating your first assignments, it is recommended to set the correct keyboard format (two-level Enter – `ISO`, otherwise – `ANSI`) and adjust the visual settings for comfort (the `GUI` tab: gui scale, reference height, font scale and name).  

---

**That’s it – everything else comes down to how you set things up.**
<br>

# 🤝 Support

Any kind of contribution is welcome!

- Suggest ideas for new features and improvements  
- Contribute useful layers and custom functions  
- Share the project with friends, colleagues, or your subscribers  
- If you create videos – Cadans really shines in motion, and this kind of overview is still missing
- Support development directly: [$](https://ko-fi.com/uqqu_) / [₿](https://nowpayments.io/donation/uqqu)
<br>

> 🚧 The project is under active development – if you run into any issues, please [report them](https://github.com/uqqu/Cadans/issues).