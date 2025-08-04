# Neuro-sama Balatro AI Integration

A comprehensive Balatro mod that integrates with the Neuro-sama SDK to enable autonomous AI gameplay. This mod allows the AI VTuber Neuro-sama to play Balatro independently while viewers watch, with seamless WebSocket communication and intelligent game state analysis.

## Features

### 🔧 **Mod Compatible**
- Dynamic card descriptions read from UI rendering (not hardcoded)
- Should work with any custom jokers/consumables from other mods

### 🤝 **Co-op Ready**
- Actions and context mirror real-time game state for multiple observers
- WebSocket API enables external tools and AI integration
- State-validated actions prevent desync issues

## Installation

### Requirements

- Balatro (Steam version recommended)
- [Steamodded](https://github.com/Steamopollys/Steamodded) modding framework
- Neuro-sama SDK running on localhost:8000

### Installation Steps

#### Windows (Steam)
1. Install Steamodded following their [installation guide](https://github.com/Steamopollys/Steamodded#installation)
2. Navigate to your Balatro mods directory:
   ```
   %APPDATA%/Balatro/Mods/
   ```
3. Create a new folder called `NeurosamaBalatro`
4. Copy all mod files into this directory
5. Ensure your directory structure looks like:
   ```
   %APPDATA%/Balatro/Mods/NeurosamaBalatro/
   ├── NeurosamaBalatro.json
   ├── NeurosamaBalatro.lua
   ├── neuro/
   ├── ...
   └── README.md
   ```
6. Launch Balatro - the mod should appear in the mod menu

### Neuro-sama SDK Setup

1. Ensure the Neuro-sama SDK is running and accessible on `localhost:8000`
2. The SDK should expose a WebSocket endpoint at `ws://localhost:8000/ws`
3. Verify the connection by checking the mod's debug output



### TODO's
- [ ] Fix boss effect in blind/game context
- [ ] Implement run end (win/lose) actions
- [ ] Check card context (with seals and such)
- [ ] Implement all pack opening actions (only simple card selection is working currently)
- [ ] Clean up some blind context (not always include 'Current Blind:\n Required Chips: 0')
- [ ] Implement joker unlocked acknowledgement actions
- [ ] Implement view deck action (and go back)
- [ ] Implement view collection actions
- [ ] Create context updates about hand evalutions
- [ ] Support multiple websockets?


### WIP:
- [ ] Unlock notifications / overlay processing;
   - Notifiction is generic, not containing specific informations
   - Not having the overlay context being send, not making action available to close it