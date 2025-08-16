# No Rush - Godot Game Project

## Project Overview
"No Rush" is a 3D survival game built in Godot 4.4 where the player must balance speed and stress to survive in a dynamic open world. The core gameplay revolves around an anti-speed mechanic where moving too fast increases stress and damages health, eventually leading to explosive death.

## Game Concept
The game challenges traditional "go fast" mechanics by penalizing speed:
- **Base Concept**: Moving fast builds stress and damages health
- **Core Challenge**: Balance movement efficiency with survival
- **Punishment System**: High stress/low health leads to explosive death with gore effects
- **Lives System**: 10 lives total, respawn after explosions
- **Scoring**: Based on distance traveled per time (efficiency-based scoring)

## Technical Architecture

### Core Systems

#### Player System (`Player.gd`)
- **Movement**: WASD controls with acceleration/deceleration
- **Stress System**: Builds when speed > 30% of max speed, decays when slow
- **Health System**: Damages when speed > 60% of max speed, regenerates when slow and low stress
- **Explosion Mechanics**: Triggered by critical stress (≥8.0) or zero health
- **Debug Mode**: Secret "iddqd" cheat for godlike speed
- **Scoring**: Real-time calculation of distance/time efficiency

#### Terrain System (`TerrainManager.gd`)
- **Procedural Generation**: Chunk-based infinite terrain using mathematical functions
- **LOD System**: Multiple levels of detail based on distance from player
- **Height Functions**: Complex layered noise using sin/cos wave combinations
- **Performance**: Chunks load/unload dynamically based on render distance

#### Explosion System (`ExplosionSystem.gd`)
- **Gore Generation**: Creates 15 random debris pieces with physics
- **Blood Effects**: Spawns blood splatters using decals and particle drops
- **Visual Variety**: Random shapes (boxes, spheres, cylinders, prisms) with red materials
- **Cleanup**: Automatic fade and removal after 25 seconds

#### Camera System (`ThirdPersonCamera.gd`)
- **Third Person**: Follows player with configurable distance and height
- **Manual Control**: Arrow keys for camera rotation (horizontal/vertical)
- **Smooth Following**: Lerped movement for smooth camera transitions
- **View Constraints**: Vertical angle clamped between -60° and +60°

#### Environment Systems
- **Day/Night Cycle** (`DayNightCycle.gd`): 10-minute cycles affecting lighting and ambient colors
- **Bush Spawning** (`BushSpawner.gd`): Procedural vegetation using chunk-based clustering
- **UI System** (`UI.gd`): Real-time HUD showing speed, health, stress, lives, time, distance, score, and FPS

#### High Score System (`HighScoreManager.gd`)
- **Persistent Storage**: Saves top 10 scores to user data
- **Score Tracking**: Records score, distance, time, efficiency, and date
- **Ranking System**: Automatic ranking and high score detection

## File Structure
```
/
├── project.godot           # Main project configuration
├── Main.tscn              # Main scene file
├── Player.gd              # Player controller and game logic
├── TerrainManager.gd      # Procedural terrain generation
├── ExplosionSystem.gd     # Gore and explosion effects
├── ThirdPersonCamera.gd   # Camera controller
├── UI.gd                  # User interface management
├── DayNightCycle.gd       # Environmental lighting
├── BushSpawner.gd         # Vegetation spawning
├── HighScoreManager.gd    # Score persistence
├── Assets/
│   ├── blood.tga          # Blood splatter texture
│   ├── bush.tga           # Vegetation texture
│   ├── flesh.tga          # Flesh texture
│   ├── flesh_high.tga     # High-res flesh texture
│   ├── grass.tga          # Grass texture
│   ├── grass_checkered.tga # Checkered grass texture
│   ├── flesh_cube.glb     # 3D flesh model
│   ├── notes_1.png        # Game notes/documentation
│   └── icon.svg           # Project icon
```

## Game Mechanics

### Speed vs Survival Balance
- **Base Speed**: 0.5 units/sec (safe baseline)
- **Max Speed**: 15.0 units/sec (dangerous territory)
- **Stress Threshold**: 30% of max speed starts building stress
- **Damage Threshold**: 60% of max speed starts health damage
- **Critical Stress**: 8.0/10 triggers explosion
- **Health Range**: 0-100, death at 0

### Controls
- **Movement**: WASD keys
- **Camera**: Arrow keys for rotation
- **Debug**: Type "iddqd" for debug mode (5x speed, cyan color, no stress/health)

### Visual Feedback
- **Stress Indicators**: Player shakes and turns red as stress increases
- **UI Color Coding**: Green/Yellow/Red indicators for all vital stats
- **Gore System**: Realistic explosion effects with physics-based debris

## Development Commands

### Running the Game
- Open project in Godot 4.4+
- Press F5 or click "Play" to run
- Main scene: `Main.tscn`

### Project Settings
- **Target Resolution**: 1920x1080 (fullscreen mode 2)
- **Rendering**: Forward Plus pipeline with 2x MSAA
- **Physics**: Default 3D physics with gravity

## Code Patterns and Conventions

### Architecture Patterns
- **Node-based Architecture**: Standard Godot scene tree structure
- **Component Systems**: Separated concerns (terrain, UI, player, etc.)
- **Event-driven**: Uses Godot signals and built-in process callbacks
- **Data Persistence**: JSON-based high score storage

### Performance Optimizations
- **Chunk-based Loading**: Terrain and vegetation load/unload based on distance
- **LOD System**: Multiple detail levels for distant terrain
- **Object Pooling**: Explosion debris with automatic cleanup
- **Efficient Rendering**: Billboard vegetation, optimized materials

### Code Style
- **Naming**: snake_case for variables and functions
- **Exports**: @export for designer-configurable parameters
- **Type Hints**: Used throughout for better IDE support
- **Comments**: Minimal, code is mostly self-documenting

## Technical Notes

### Godot Version
- **Engine**: Godot 4.4 with Forward Plus rendering
- **Language**: GDScript only (no C# despite .NET configuration)
- **Features**: Uses modern Godot 4.x APIs and syntax

### Performance Considerations
- Terrain generation is CPU-intensive but manageable with chunk system
- Explosion system creates many temporary objects but cleans up automatically
- UI updates every frame but uses simple operations

### Extensibility
- Modular system design allows easy addition of new features
- Export parameters make gameplay balancing accessible to designers
- Procedural systems can be easily modified or extended

## Security Analysis
- All code appears to be legitimate game development code
- No network functionality or external data access
- File I/O limited to local high score saving
- No executable code generation or unsafe operations

This is a well-structured indie game project focusing on an innovative anti-speed mechanic with solid technical implementation and engaging visual feedback systems.