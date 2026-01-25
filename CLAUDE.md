# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChristmasTree is a Delphi Firemonkey (FMX) mobile application that displays an interactive Christmas tree with twinkling lights and breakable ornaments. The application uses a real Christmas tree image (ChristmasTree.png) as the background with interactive ornaments overlaid on top. This is a single-form application targeting Windows, Android, and iOS platforms.

## Build Commands

**Open Project:**
```
Open ChristmasTree.dproj in Embarcadero RAD Studio
```

**Build for Windows:**
- Select Win32 or Win64 platform in RAD Studio
- Press F9 or use Project > Build

**Build for Mobile:**
- Select Android or iOSDevice64 platform
- Ensure SDK paths are configured in Tools > Options > SDK Manager
- Press F9 or use Project > Build

**Deploy to Device:**
- Use Project > Deployment Manager to configure deployment
- Use Run > Run Without Debugging (Ctrl+Shift+F9)

## Code Architecture

### Form Structure
- **uMainForm.pas/fmx**: Single main form containing all UI and logic
- Uses FMX.Types, FMX.Objects for visual components
- Timer-based animation loop for smooth 60 FPS rendering

### Core Classes

**TChristmasBulb**
- Encapsulates interactive ornament bulbs
- Three states: bsNormal, bsBroken, bsFalling
- Contains TCircle shape with highlight child
- Manages falling physics (velocity, gravity, rotation)
- Position, color, and state tracking

**TChristmasLight**
- Represents twinkling lights on the tree
- TCircle shape with TGlow effect component
- Random twinkle timing and opacity transitions
- Non-interactive (HitTest = False)

**TMainForm**
- Main form managing all visual elements
- Owns TObjectList collections for bulbs and lights
- Creates tree geometry using TPath for triangles
- Timer1 drives animation loop with delta-time calculations

### Animation System

**Timer-based Loop:**
- Timer1 runs at 16ms interval (~60 FPS)
- Delta-time calculation using DateUtils for frame-rate independence
- Updates light twinkle and bulb physics each frame

**Physics Simulation:**
- Gravity constant: 500 pixels/second²
- Velocity accumulation: `V += G * dt`
- Position update: `Y += V * dt`
- Rotation during fall: 200 degrees/second
- Opacity fade: 2.0/second during fall

**Twinkle Animation:**
- Each light has random initial timer offset (0-3 seconds)
- Every 3 seconds, selects new target opacity (0.3-1.0)
- Smooth interpolation using delta-time

### Visual Hierarchy

Tree structure (back to front):
1. Form background (midnight blue fill)
2. Tree trunk (TRectangle, brown)
3. Tree layers (3 TPath triangles, dark green, decreasing size)
4. Gold star on top (TPath with 5-point star geometry)
5. Twinkling lights (TCircle with TGlow effects)
6. Ornament bulbs (TCircle with highlight, interactive)
7. Garland decorations (small gold circles)

### Event Handling

**OnBulbClick:**
- Attached to each TChristmasBulb.Shape
- Sets state to bsBroken, plays sound
- Starts delayed timer (100ms) to begin falling animation
- Searches FBulbs list to find matching bulb object

### Memory Management

- FBulbs and FLights are TObjectList with OwnsObjects=True
- Automatic cleanup on form destruction
- Temporary timer for fall delay is self-freeing

## Platform-Specific Notes

**Windows:**
- Uses Beep() for break sound (conditionally compiled)
- Can use TMediaPlayer with WAV files

**Android/iOS:**
- TMediaPlayer requires deployment of sound files
- Add sound files to Deployment Manager
- Use relative paths for FileName property

## Extending the Application

**Adding Sound Files:**
1. Add WAV/MP3 to project directory
2. Configure in Project > Deployment
3. Update PlayBreakSound to set MediaPlayer1.FileName

**Adjusting Tree Size:**
- Tree coordinates are calculated from ClientWidth/ClientHeight
- CenterX = ClientWidth / 2
- Tree spans from Y = ClientHeight - 380 (star) to ClientHeight - 60 (base)
- Width varies by layer: 160, 200, 240 pixels

**Adding New Ornament Types:**
- Create new class inheriting patterns from TChristmasBulb
- Add to FBulbs list or separate collection
- Implement custom rendering and interaction

## Common Modifications

**Change tree colors:**
- Modify TREE_COLOR, STAR_COLOR constants
- Update trunk.Fill.Color

**Adjust gravity:**
- Modify GRAVITY constant (default 500)
- Higher values = faster fall

**Change light behavior:**
- Modify twinkle timer duration (currently 3.0 seconds)
- Adjust opacity ranges in UpdateTwinkle

**Add more bulbs:**
- Increase loop count in CreateBulbs
- Adjust random X/Y ranges for positioning
