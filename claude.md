# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 project for a top-down car chase game called "CarChase". The game features a player car being pursued by an AI car using line-of-sight mechanics on procedurally generated road networks.

## Development Environment

- **Engine**: Godot 4.4
- **Primary Language**: GDScript (no scripts exist yet)
- **Platform**: PC (Windows, macOS, Linux) with potential web export
- **Rendering**: GL Compatibility mode

## Project Structure

The project is in early development with only basic setup:
- `project.godot` - Main Godot project configuration
- `assets/road_tiles/` - Contains road tile assets for the procedurally generated road system
- `Car Chase Game Design Document.md` - Comprehensive game design documentation
- `icon.svg` - Project icon

## Development Commands

Since this is a Godot project, development is primarily done through the Godot editor:
- Open project in Godot 4.4 editor
- Use F5 to run the project
- Use F6 to run the current scene
- Export through Project � Export menu

## Architecture Overview

Based on the design document, the planned architecture includes:

### Core Systems
1. **Map Generator** - Creates random road networks using TileMap
2. **Vehicle Controller** - Handles player input and CharacterBody2D physics  
3. **AI System** - Manages AI behavior states using Navigation2D pathfinding
4. **Line of Sight System** - RayCast2D for visibility detection
5. **Game Manager** - Handles game states and scoring using signals

### Planned Node Structure
```
Main (Node2D)
   GameManager (Node)
   MapGenerator (Node2D)
      RoadTileMap (TileMap)
   Player (CharacterBody2D)
      PlayerSprite (Sprite2D)
      PlayerCollision (CollisionShape2D)
      PlayerController (Node - Script)
   AIChaser (CharacterBody2D)
      AISprite (Sprite2D)
      AICollision (CollisionShape2D)
      DetectionArea (Area2D)
      LineOfSightRay (RayCast2D)
      AIController (Node - Script)
   Camera (Camera2D)
   UI (CanvasLayer)
       HUD (Control)
       PauseMenu (Control)
```

## Key Implementation Details

### Road Generation
- Uses TileMap with custom tile set for road pieces
- Road tiles are available in `assets/road_tiles/` with various configurations (corners, intersections, T-junctions)
- Generates NavigationRegion2D for AI pathfinding
- Implements collision layers for road boundaries

### AI Behavior
- NavigationAgent2D for pathfinding along road network
- Area2D for detection radius  
- RayCast2D for line-of-sight checks
- State machine with Detection, Chase, Search, and Idle states

### Physics
- CharacterBody2D for both player and AI vehicles
- Arcade-style movement with acceleration/deceleration
- Turning radius based on speed
- Top-down 2D perspective with Camera2D following player

## Development Phases

1. **Phase 1**: Core Systems - Basic vehicle movement, simple road generation, camera system
2. **Phase 2**: AI Implementation - AI vehicle movement, line of sight detection, basic chase behavior
3. **Phase 3**: Polish & Features - Visual improvements, audio integration, UI implementation
4. **Phase 4**: Testing & Refinement - Bug fixes, performance optimization

## File Organization

- All road tile assets are in `assets/road_tiles/` with corresponding .import files
- Game design documentation is in `Car Chase Game Design Document.md`
- No scripts or scenes exist yet - project is in initial setup phase