[🇬🇧 English](README.md) • [🇷🇺 Русский](README.ru.md)

# Cadans

Welcome to **Cadans** — a global remapper of any input events. Set dozens and hundreds of assignments for any, up to the most exotic events for any keys, mouse buttons or its movement – gestures. Create chains of assignments with your own unique actions, from typing template text to accessing external api. Without firmware, drivers or special hardware – works with any device.


## 🚀 Key Features & Interactions

> All animations and their individual frames are slowed down for readability.

### **> Tap-Hold**  
Basic events of any key, branching of which opens the first level of variability. Add two assignments to a key – one for a quick press and one for a short hold.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/1.gif" width="400">
  
  
Here and hereafter: no functionality overrides native behavior in general. If there is no assignment, as here for holding a particular key, there will be the expected system result.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/2.gif" width="400">
  
  
### **> Sequences of events**  
Each event doesn't just perform the assigned action, but is a chain element for unique nested assignments. With support for tap and hold branching, of course.  
With each new triggered event, you move on to the next assignment until you reach the end of the chain, performing the final action, and return to the beginning. If an event at the first level has no child assignments, it is also a chain, just of one element, and the action is performed immediately.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/3.gif" width="400">
  
  
The chain can also be interrupted by performing an action of the current element before reaching the final one. In the most basic case, this is a timer interrupt. If the next event has not occurred, we perform the action of the current one.
There are no depth limitations for chains – Morse code, autocorrect for words, whatever you can think of. Each press is potentially a new level and a new field for assignments.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/4.gif" width="400">
  
  
You can use chains only for final actions, where intermediate events are ignored, or you can specify additional actions, at any level. As in the following example – the most common input is performed, but it's actually a progression through the chain with an additional final action. It's a bit of a joke, but it works.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/5.gif" width="400">
  
  
### **> Custom modifier keys**  
Also any key/button on hold can be assigned as a modifier for other events with more and more fields for assignments. Modifier combinations also have their own “fields”. Pressing a modifier is not a separate transition in the chain, but it modifies the others on its own level.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/6.gif" width="400">
  
  
### **> Chords/combo**  
Add an assignment to an entire combination of keys at once, which will trigger when they are pressed together. This too can be a chain element, up to and including a chain of just chords.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/7.gif" width="400">

> Each level of each sequence is assigned independently of the others, and a single key can be both a modifier and part of a chord, and have its own events and transitions. Each new level is a new, clean field for assignments.  
`\[mod]+e, \ (tap), \ (hold), chord(\+z+x) 🡒 ƒ Turn on Pomodoro-timer`

### **> Gestures**
And at the same time, each assignment (except for chords) can also be a trigger for new events – gestures. If one or more child gestures are added to an assignment, mouse movements will leave a trace while holding down the assigned key, and releasing it will execute the action of the gesture if a match is found. Gestures are complete elements of chains, and in the same way can be continued by any further events, including assignments with all new gestures. Having gestures under an assignment does not override other child assignments, but complements them, and you can continue the chain with a gesture or any other event. Whichever event is triggered, we'll move on to that one.  

![](https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/8.gif)  
  
  
Each gesture can also be given its own recognition options, such as: independence from the figure rotation, from the drawing direction, the scale influence, and for closed figures the option of independence from the first point of drawing is also available, when the figure is important, not the drawing order. All options can be combined in a single gesture and in different gestures at the same level, as desired. Assignments where gestures start also have their own settings for them, but already graphical – line colors, position and visibility of the live recognition text.  

![](https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/9.gif)  
  
  
On top of all this, gestures are divided into 9 independent pools – 4 edge pools, 4 corner pools, one center pool, depending on where the gesture was started drawing from. This not only logically separates the categories of assignments and increases their possible number, but also allows you to set more precise assignments in combinations with native behavior, because the start of drawing and recognition is triggered only when the assigned event does not just have child gestures, but when they are in the pool at the current cursor position. This means you can set assignments for part of the pools without changing the behavior outside of them, as in the example below, where there are assignments for all but the central pool under the RMB. Again, no overriding actions if they don't lead to anything.  

![](https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/rmb%20gestures%20demo.gif)  

The last example is not artificial, but one of the preset layers in action, which you can try as is, and adjust to your needs if you wish.  

### **> Final actions and fine-tuning assignment options**  
As final and intermediate actions you can set... anything? Character, text, simulation of other keys, native behavior, execution of any function. And the last ones don't necessarily have to be related to input.  

<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/10.gif" width="600">
  
And to configure any desired behavior, assignments can also be used to specify parameters for triggering related events by overriding global ones – hold threshold, child event waiting time (if there is any), behavior at child events without assignments, instant/intermediate execution, saving at this level of transitions, additional action when releasing a key, as well as suggestive text in the GUI and color settings when drawing child gestures.

### **> Other**

### Layers
All assignments are saved in their own files – layers – which can be separately customized, grouping assignments by logical categories and usage scenarios, and toggling work specific to the moment. Each layer is managed separately, and current assignments are collected from all active layers. Switching layers or sets of layers can be part of your assignments – add enabling a layer as an assignment action.  
`\+1 🡒 Toggle navigation layer activity`  
`\+2 🡒 Turn off all layers except *n*`  
`\+3 🡒 Enable layer set *abc*`

#### Individual assignments for language layouts
In addition to global assignments, you can also link assignments to specific language layouts.  
[en] `o (hold) 🡒 “`, `. (hold) 🡒 ”`  
[de] `o (hold) 🡒 „`, `. (hold) 🡒 “`  
[ru] `o (hold) 🡒 «`, `. (hold) 🡒 »`  
[no] `a, e 🡒 æ`

### **> Any keys and buttons**  
All keyboard keys are supported, including an additional row of multimedia/office keys, virtually assigned f13-24 and all mouse events up to horizontal scrolling and gestures.  

> The additional multimedia-office row and mouse scroll do not support hold events, and system modifier keys are prohibited from assigning press events for security reasons. They also cannot be used for chords. Everything else is completely available.

### **> Dividing into layers**  
Organize assignment groups into different layers: basic assignments, extended characters, navigation, media control, etc.  
Each layer is managed separately, and current assignments are collected from all active layers.

Switching layers or groups of layers can be part of your assignments – add layer activation as an action for an event.  

You can set assignments for different layouts on each layer.

### **> GUI**

All of the above is assigned and configured via the GUI.

![](https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/1i.png)

Go through any sequence of events, add assignments, link them to existing layers, or create new ones.  
All assignments, with additional indicators, the number of child transitions, and the display of cross-assignments from different layers—everything is right in front of your eyes. For example:

![](https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/2i.png)
> A modified layout is not a reassignment, it is simply a [different layout](https://github.com/uqqu/qPhyx_layout)

All added assignments become available for use immediately. Change functionality on the fly.


## 🎮 Usage

0. **Clone** this repo
    - *(optional)* Install AutoHotkey v2
1. **Run** `main.exe` or `main.ahk`
   - When you first launch the app, cycle through all your installed layouts and configure the display and behavior of the GUI via 🔧 in the lower right corner
2. **Try** some of predefined layers
3. **Define** your own assignments
4. **Use** new assignments immediately, without restarts

### 🔧 Prerequisites

- Windows 10+
- *(optional)* AutoHotkey v2


## 🖥️ Detailed description of the GUI  *;TODO*

> Alternative description in article format [on Habr](https://habr.com/ru/articles/900000/) (in Russian)

### 🗺️ Visual Cues & Navigation

#### **Keyboard/mouse buttons**
The text on the button — assignments on tap (above) and hold (below), if any. Each assignment can have a name added to it, which will be displayed in the GUI instead of the value itself.

Colored frame — indicates a special type of hold: yellow indicates chord components; blue indicates user modifiers; black indicates currently active in the GUI modifiers that are taken into account for displaying current assignments.

Additional colored indicators display the fine-tuned settings for each assignment: at the top of the button for the base assignment; at the bottom for the hold assignment. In the right corner, a red counter or simply an indicator (changeable in settings) displays the number/availability of child transitions (also works for modifiers, including combined ones). On the left side are indicators of changed click settings. In order of display:  
- The silver indicator shows that the name for the GUI of the assignment has been changed (to avoid confusion)
- Gray – a non-returnable assignment has been set
- Teal – independent activation
- Blue – additional action on release
- Purple – modified hold activation time
- Pink – modified waiting time for the next press for child transitions (only for the next level)

In the upper right corner, there is a non-clickable information button that displays the current value of active GUI modifiers or their combinations.
Mouse buttons are located around the numpad. The display of additional rows of keys can be enabled in the settings, if necessary.

#### **Transitions**
Pressing and holding physical keys on the keyboard/mouse will take you to the corresponding level of the assignment chain. Alternatively, use the mouse – left click to move with a tap event, right click to hold event. After moving, new items will open for editing or clearing values along the current path.

#### **Path**
Above the layout template is a menu showing the path to the current level of the chain (the current destination node).

The arrows indicate the type of transition: ➤ for a tap, ▲ for a hold, and ▼ for a chord. If the arrow is accompanied by a number (such as `2➤`), it means that this transition was performed with the corresponding modifier value (this can be either a single modifier or a combination of modifiers – based on the sum of their values).  
To return to any of the previous levels, click on the corresponding label. The transition modifier value for that level will be saved. Clicking on the current level label (the last one in the path) will reset all active modifiers.

### ⌨ Layouts
You can create assignments for a single keyboard layout or global, for all of them at once.

Near the settings button, there is a drop-down list with your layouts (as well as global assignments – `Global`). Layouts found in your layers will also be added to this list, even if these layers are inactive (configurable).
> In the GUI, for greater control, you can see global assignments and assignments for each layout separately. But during the execution of the main script, these assignments are mixed — **global assignments are added to each layout**, with priority given to specific layouts in case of cross-assignments. For example, when assigning [Global] `o (hold) 🡒 "`, `. (hold) 🡒 "` and [en] `o (hold) 🡒 “`, `. (hold) 🡒 ”`, the assignment “” will work when the en layout is active, and "" on all others.

### 🌫️ Layers
The list on the left displays all layers found in `layers\` `*.json`. Set the layer activity by changing the checkbox. To interact with layers, use the buttons below the list – change its relative priority (this affects cross-assignments), edit the name, delete and add new ones.

Double-clicking on any layer will take you to a separate viewing and editing mode for that layer, without being tied to the currently active layers.

Also, the list of layers at the root level displays the total number of assignments on different layouts, and – at specific transition levels, – it displays assignments and the number of transitions from it from different layers *along the current path*. You always know what is happening on this node on all layers. By default, values from inactive layers are not collected or displayed for better performance, but you can temporarily change this behavior in the settings.

### 📌 Predefined layers
Several layers are placed directly in the repository so that you can familiarize yourself with the usage and capabilities before assigning your own or adapting existing ones to suit your needs:
- **Default**: 83 additional extended punctuation characters in the alphabetic part with only one modifier.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/b764bb7c-b1ee-4490-9306-9f9a07638aa2)
  ![](https://github.com/user-attachments/assets/d957a3eb-41cb-4100-b6b4-bde7911fa9d7)</details>
- **Controlling Keys**: a new perspective on the familiar positioning of control keys. It also features additional media keys, hjkl navigation, and several everyday functions, such as increasing/decreasing the number under the cursor, CAPS on one word, delayed start/stop of music, and other small features.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/0420b99f-03ad-43e0-a772-c200ff4d605d)
  ![](https://github.com/user-attachments/assets/13ff030d-20a1-4634-bc5d-0f8751ce6b78)</details>
- **Leader**: a dozen functions under a single button. As a template for your customization.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/c48be9bd-3297-4bd7-a2dc-18baa88507a2)
  ![](https://github.com/user-attachments/assets/c005c286-41a2-4f42-bdb6-391e1c800a9c)</details>
- **Mouse**: 38 ~parrots~ assignments for quick access using all mouse events via side modifier buttons and their combinations. From navigation and media control to random password generation and link shortening functions.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/74f43968-ecfa-4ced-b3c2-8fd56b7b948b)
  ![](https://github.com/user-attachments/assets/362e57fc-2c6a-41eb-bae3-418de6875e34)
  ![](https://github.com/user-attachments/assets/f374cbf5-0dfb-4f74-a5b6-be025f2b54ed)</details>
- **Emoji**: and how many of them are there?..<details><summary></summary>
  ![](https://github.com/user-attachments/assets/ce50189f-6fd5-432b-a56f-460906bb042b)</details>
- **Extra langs**: yoü use å separate łayout for a couple of ñew letters? There are 12 for each script, and a whole row of global diacritics. Write in any language ø. *(layout đependent)*<details><summary></summary>
  ![](https://github.com/user-attachments/assets/bd888770-de73-40ac-aeea-2b5bb59c0ad5)
  ![](https://github.com/user-attachments/assets/1adcef14-dbb8-40bf-a1be-a0ac55fea6f9)
  ![](https://github.com/user-attachments/assets/5e8fb2de-a09a-4188-9dbb-4e541022165a)</details>
- **Morse**: you’ve only seen it on TV? You can try it for yourself.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/8f5be4a9-0595-4c68-b852-47c6b2e3e13a)
  ![](https://github.com/user-attachments/assets/92505abe-7c6d-4e6f-a932-511e5ee107b8)</details>
- **Angry**: one of the variants of using the `Instant` option. Don’t swear.<details><summary></summary>
  ![](https://github.com/user-attachments/assets/50c1a660-40d2-4b7e-8684-5aead1b2988f)</details>
- **NumLock** and **One word caps**: auxiliary layers toggled from other layers via the custom `ToggleLayers` function.
- **…and a lot more of your own?**

### 🎨 Defining first assignments
To add or change an assignment, press the corresponding key on your keyboard/mouse or click on it in the interface. After pressing, the `Base` and `Hold` panels will appear in the upper right corner. `Base` is responsible for the assignment on tap, and `Hold`, respectively, when held down. Clicking on them will open a form for changing/adding an assignment.

#### Types of actions
There are several types of actions that you can select for assignment in the corresponding list:
- **Plain text** – any string you would like to enter. Some unique symbol, your duty email, a cherry pie recipe, whatever you want.
- **Key simulation** – commands in AHK-syntax, like `{SC010}`, `+^{Left}`, `{End}{Shift down}{Home}{Shift up}{Backspace}`, to simulate certain keystrokes. You can read the syntax in detail on the [AHK website](https://www.autohotkey.com/docs/v2/KeyList.htm).
- **Modifier** – when creating an assignment for hold action, the modifier type is available. When assigning this type, specify its numerical value (usually just an ordinal number), which will be used for assignments from it. Combined modifiers are obtained from the sum of the values of **different** assigned modifiers.
- **Disabled** and **Default** – are basic types that may be needed when configuring auxiliary keys in a transition chain.
- **Function call** – any of the existing ones, or your own AHK function, such as `SendCurrentDate` or `ExchRates(USD, RUB)`.
  - String values are specified *without* quotation marks, and `,` and `[` in strings should be escaped with `\`; if the function does not accept parameters, you can omit the parentheses, leaving only the function name.
  - To simplify assignments, main user functions can be assigned via a submenu that appears when the corresponding menu item is selected.  
![](https://github.com/user-attachments/assets/24b91c96-e602-483c-805e-1e627c90c506)

#### Additional parameters
In addition to selecting the action type and the action value itself, you can also set additional parameters such as:
- Instant activation – makes the assignment independent of child transitions, performing the assigned action immediately when the event is triggered. The chain of transitions is not lost and you can continue diving.
- Irrevocable press – prevents returning to the root from the current press. Normally, the return occurs when the leaf (the last element of the assignment chain) is reached, or when the timer for waiting for the next press (if any) expires. With this option this does not happen, and you remain at the current level if there are no child assignments, or in an unlimited wait for the next press. By default, irrevocable option is offered for all assignments from under modifiers, to allow multiple value entry.
- Modified hold timeout – the value in ms that will be used to distinguish tap/hold, instead of the globally specified value. ⚠ This applies specifically to base assignments. In other words, you specify when the base event will turn into a hold event.
- Modified child press wait time – like the previous one, in ms, replaces global. Works only for one level under the given assignment.
- Additional release action – calls another action of the specified type and value when the key of the catched assignment is released. The action will be recorded at the moment of catching the whole assignment, and will not be broken by any transitions.
- GUI shortname – purely for visually enhancing your layers in the GUI. Useful for almost all assignments except single character texts.

If you’re in edit mode for a specific layer, or if you have only one active layer, the assignment will be automatically linked to it. Otherwise, an additional list is displayed to select the layer to which the assignment will be linked.

> System modifier keys can only be assigned a user modifier action, without other settings.

### ✨ How it works

When you press a key, the script checks if there is in the current transition table both base and hold assignments.
- If there is only the base, it goes into the next check. No unnecessary branching delays if they are not needed.
- If there is a hold assignment, the program checks if the key will be held for the specified number of ms.
- Releasing the checked key before the timer is considered as a basic tap.
- Holding for the specified time will send the hold assignment to the next check, without being tied to the subsequent release of the key.

#### Transition
After determining the assignment (tap or hold) it checks its own nested transition table. If it is not empty, the link to the current transition table/node is changed, and the script waits for the next event based on the global (or specified for this assignment) timer value, without performing the current assignment action. If the `Instant` option is added to the assignment, the action will be performed immediately, and the link to the table will also move to the next node, waiting for a new key.
- If there are no new events for the given timer, the last action will be executed (hereinafter – if not already executed by `Instant`) and the transition table returns to the root table, if the `Irrevocable` option is not specified.
- If there is no assignment for the next event in the current transition table, the previous, unsent assignment is executed, and the new event is processed from the root transition table.
- If the event from the next press is present in the transition table, it starts from the first point of this paragraph (from checking the base and hold assignments for the pressed key/button, …).

#### Return to root
Every time you reach the last event in the chain (leaf), or if the chain is interrupted by a timer, the table returns to the root state, except in cases of `Irrevocable`.

#### Timer delay
Special hold types such as `modifier` and `chord part` delay the timer, and while the corresponding keys are held down, table reset and action executing do not occur.

#### No-return event
By default no return occurs when entering via `modifier`. As long as the modifier is held down, you can perform any number of keystrokes for the current table, and the return will only occur when the modifier is released.
- But this does not prevent from moving to deeper levels of nesting. The transition, even with a modifier, returns us to the second point of the block (from checking the nested table).
- Also, with each transition, the value of the mismatched modifiers is reset, and the timer delay no longer works.

#### Return transition
Every time you reach the last assignment in the chain, you return to the initial table. But not in the case of modifiers – pressing them by default keeps you at the current node, allowing you to access any number of assignments along that path. Even pressing non-assigned keys at this node will not reset you. The return will occur when you release all modifiers. But you can still go deeper if the local assignment have a non-empty transition table, in which case the previously active modifier will no longer serve as protection against reset.

#### Modifiers in the GUI
Assigned modifiers are displayed with a blue border, while currently active (held down) modifiers change their border to black. The total value of active modifiers is displayed on the auxiliary button in the upper right corner of the keyboard layout.  
The values of the modifiers themselves are displayed at the bottom of the button, as are other hold values (if no custom name is specified).  
To toggle modifier activity in the GUI, right-click on it or hold down the corresponding physical key (except Alt and LBM-RBM).  

> Pressing modifiers does not affect the transition; they only change a single value within a current node, which will be taken into account for other assignments.

### 🎶 Chords
The right list shows chords valid at your current path. Click `New` to enter chord‑selection mode, press or click your desired combination, then assign it just like usual tap/hold value.

> If two chords share a common key combo, both will fire when pressed.

#### Chord nesting
Chords themselves can nest further. You can add assignment under chord, chord under chord, whatever you like. Double-click on a chord line to jump to the nested table.

#### ModChords
Chords work with modifiers, and although mechanically it is one large chord, modifiers are not considered to be keys within it. When you add or edit a chord, the currently assigned modifiers are not selectable. Also, mouse buttons and additional multimedia-office row keys are not available for chords.

#### Overrides
A `chord part` is a separate hold type, so when adding/modifying a chord, existing hold values of other types in the keys involved **will be overwritten**.

---

## 🗂️ JSON Layer Format

Layers live in `layers/` as JSON files. Each file is a Map where:

```jsonc
{
  "<LAYOUTID>": [  // "0" for global assignments
    "gesture_options",  // string (color options for gestures from this node)
    {  // scancodes map
      "<scancode>": {
        "<modifier>": [
          "action_type",              // int (1-7)
          "value",                    // string
          "up_action_type",           // int (1-7)
          "up_value",                 // string
          "is_instant",               // bool
          "is_irrevocable",           // bool
          "custom_long_press_time",   // int (0 as default)
          "custom_next_key_time",     // int (0 as default)
          "unassigned_child_behavior" // int (1-5)
          "gui_shortname",            // string
          "<nested>"  // -> [gesture_opts, scancodes{}, chords{}, gestures{}]
        ],
        //...
      },
      //...
    },
    {  // chords map
      "<chord_scancodes>": {
        "<modifier>": [
          "action_type",
          // …and all the same structure
          "<nested>"
        ],
        //...
      },
      //...
    },
    {  // gestures map
      "<pool+vectors>": {
        "<modifier>": [
          "action_type",
          // …and all the same structure
          "<nested>"  // (gesture_opts here contains the own recognition options)
        ],
        //...
      },
      //...
    }
  ],
  //...
}
```

---

## 🤝 Contribute

All contributions welcome! Please open issues or PRs for new features or improvements.

The easiest ways to contribute:
- **Layers** – suggest your own unusual, useful, or just amusing uses for the project. It’s always interesting.
- **Functions** – an endless field of suggestions, it can be really anything. But if it’s useful to you, it might be useful to someone else.
- **GUI** – lots of valuable little things to fix.
- …and of course you can just spread the word and share the link with your friends, acquaintances, and, maybe, subscribers 👾

> 🚧 The project is under active development and may contain bugs.
> Please report all problems and suggestions in the Issues section.