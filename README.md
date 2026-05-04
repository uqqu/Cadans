<p align="center">
<img src="https://raw.githubusercontent.com/uqqu/.other/refs/heads/master/readme_images/Cadans/demo.gif">
</p>

##

Welcome to **Cadans** – an input customization tool that lets you assign actions to keys, combinations, and gestures.  
Simple taps, holds, chords, modifiers, and multi-zone mouse gestures can all be combined and used in the way that suits your workflow.  

Any event can trigger an action – from inserting text or symbols to controlling the system or running custom logic.  
These assignments can be chained together, forming sequences of transitions with intermediate and final actions.  

Assignments can be defined per application and per keyboard layout, grouped by use case, and switched on the fly.  
Cadans runs on Windows and supports any keyboard and mouse, treating them as a unified input system – no firmware or special hardware required.  

Only what you assign is affected – everything else remains native unless explicitly overridden.  

Use individual features – basic remapping, gesture controls, or a single key for custom functions in a specific app.  
Or go further and build more complex logic – it’s entirely up to you.  
<br>

# Overview

> Any `input` → with any `conditions` → can produce any `event` → and become an `assignment` in a system of actions and transitions

<table>
  <tr>
    <th colspan="2">Input</th>
  </tr>
  <tr>
    <td><strong>Keyboard</strong></td>
    <td>
      <p>✅ Full keyboard support, including system modifiers and extended keys</p>
      <p>⚠️ <b>Alt</b> and <b>Win</b>: hold-based events only</p>
    </td>
  </tr>
  <tr>
    <td><strong>Mouse</strong></td>
    <td>
      <p>✅ All mouse buttons and wheel scrolling are supported</p>
      <em>
        Wheel scrolling has no hold state by nature, so only trigger events are available<br>
        For safety, LMB and RMB are available everywhere except the base level (gestures are allowed)
      </em>
    </td>
  </tr>

  <tr>
    <th colspan="2">Conditions</th>
  </tr>
  <tr>
    <td><strong>Layouts</strong></td>
    <td>✅ Separate assignments per keyboard layout, plus global ones</td>
  </tr>
  <tr>
    <td><strong>Processes</strong></td>
    <td>✅ Separate assignments per application, on demand</td>
  </tr>
  <tr>
    <td><strong>Layer activity (dynamic)</strong></td>
    <td>
      <p>✅ Active layers act as conditions and can change available assignments on the fly</p>
      <em>
        Note: in Cadans, layers are not modes you switch between. They are sets of assignments that stay active together and shape behavior in real time
      </em>
    </td>
  </tr>

  <tr>
    <th colspan="2">Events</th>
  </tr>
  <tr>
    <td><strong>Taps</strong></td>
    <td>✅</td>
  </tr>
  <tr>
    <td><strong>Holds</strong></td>
    <td>✅</td>
  </tr>
  <tr>
    <td><strong>Multi-threshold holds</strong></td>
    <td>❌</td>
  </tr>
  <tr>
    <td><strong>Chords / combos</strong></td>
    <td>✅</td>
  </tr>
  <tr>
    <td><strong>Custom modifiers</strong></td>
    <td>✅</td>
  </tr>
  <tr>
    <td><strong>Gestures</strong></td>
    <td>✅ (in 9 independent zones)</td>
  </tr>
  <tr>
    <td><strong><i>Notes:</i></strong></td>
    <td>
      <p>✅ Keys and hotkeys without assigned events keep their native behavior</p>
      <p>⚠️ Each key or button can have only one hold-type behavior: <i>hold</i>, <i>chord</i>, or <i>modifier</i>.<br>
      Maximum per key: <i>tap</i> + one hold-type + any number of <i>gestures</i> (in any zones)</p>
      <em>
        Event interactions and interruptions are carefully designed to behave consistently and intuitively across cases.
        If you find anything that still feels off, <a href="https://github.com/uqqu/Cadans/issues">please report it</a>
      </em>
    </td>
  </tr>

  <tr>
    <th colspan="2">Assignments</th>
  </tr>

  <tr>
    <td><strong>Actions</strong></td>
    <td>
      Any event can trigger an action:<br>
      <ul>
        <li>text or character input</li>
        <li>key simulation</li>
        <li>function calls <i>(not limited to text or input)</i></li>
        <li>helper types</li>
      </ul>
      <i>Tap</i> and <i>hold</i> can have separate press and release actions for full control.
    </td>
  </tr>

  <tr>
    <td><strong>Chains</strong></td>
    <td>
      <p>Assignments can continue into other assignments, forming chains of interactions.</p>
      <p>A single input can start a sequence that continues step by step.<br>
      Each step can either execute an action or wait for further input.</p>
      <p><b>Assignments that lead to further steps still work on their own</b> – continuation extends behavior rather than replacing it.</p>
      <p>There is no fixed depth or structure – chains can be as simple or as long as needed.<br>
      Even a single action fits this model – it is simply a one-step chain, resolving immediately.</p>
    </td>
  </tr>

  <tr>
    <td><strong>Behavior control</strong></td>
    <td>
      <p>Each assignment defines not only what happens, but how it behaves.</p>
      <p>Behavior can be controlled at multiple levels: global rules define default timing, gesture recognition, and interaction logic, while individual assignments can override these settings where needed.</p>
      <p>In addition, assignments can define their own execution and transition rules – how they resolve, whether they continue, and how the system reacts to further input.<br>
      This gives precise control over interaction flow.</p>
    </td>
  </tr>

  <tr>
    <td><strong>Layers & composition</strong></td>
    <td>
      <p>Layers form another structural plane of the system: chains define how interactions unfold, while layers define how they are combined.</p>
      <p>Layers are logical sets of assignments. All active layers work at the same time, contributing to the current behavior.</p>
      <p>They are not just static configuration: layers can be enabled, disabled, or switched dynamically as part of a workflow.<br>
      This allows modifying which assignments are available at any moment, without replacing or breaking existing interactions.</p>
    </td>
  </tr>

  <tr>
    <td></td>
    <td>
      <em>
        This is how the system comes together: assigned events form chains that evolve over time, with fine-tuned behavior and their own actions, combined across dynamic layers and conditions.
      </em>
    </td>
  </tr>

  <tr>
    <th colspan="2">Other</th>
  </tr>

  <tr>
    <td><strong>Platforms</strong></td>
    <td>⚠️ Windows only</td>
  </tr>
  <tr>
    <td><strong>Requirements</strong></td>
    <td>✅ No special hardware or firmware required – just run the program</td>
  </tr>
</table>

This is enough for a <b>quick start</b>: open the app, add your first assignments, and try them in practice.

Or enable a few preset layers – ready-made examples for different scenarios.  
Use them as-is, edit, combine with your own layers, or treat them as templates for something completely different.  
If you prefer to see how it looks first, with several examples including gestures, see [Preset layers](../../wiki/🧰-Preset-layers).

##

To see how it all works in detail, step by step:

- [Step-by-step concepts](../../wiki/📘-Step‐by‐step-concepts) – from basic events to gestures, conditions, layers, and how chains work and interact
- [GUI detailed overview](../../wiki/🖥%EF%B8%8F-GUI-detailed-overview) – every control, option, and interaction in the interface
- [Creating assignments](../../wiki/🛠%EF%B8%8F-Creating-assignments) – building assignments in the GUI, with all behavior and chain options explained in context
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