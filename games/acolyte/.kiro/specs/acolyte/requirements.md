# Requirements Document: Acolyte - Bash Roguelike Game

## Introduction

Acolyte is a terminal-based roguelike dungeon crawler game written in Bash. Players explore a 16x16 dungeon, combat monsters, collect equipment and items, level up skills, and attempt to reach the dungeon exit. The game features a comprehensive skill tree system, inventory management, save/load functionality, multiple difficulty levels, and an achievement system.

## Glossary

- **Acolyte**: The player character, a dungeon explorer
- **Dungeon**: The 16x16 grid-based game world
- **Tile**: A single cell in the dungeon grid containing a wall, floor, item, enemy, or exit
- **Combat**: Turn-based battle between the player and an enemy
- **Skill**: A player ability that can be upgraded to enhance combat or exploration
- **Equipment**: Items that provide stat bonuses when equipped
- **Save Slot**: A numbered storage location for game state persistence
- **Difficulty Level**: A setting that adjusts enemy strength and game challenge
- **Achievement**: A milestone reward for completing specific in-game accomplishments

## Requirements

### Requirement 1: Dungeon Exploration

**User Story:** As a player, I want to explore a 16x16 dungeon, so that I can find items, defeat enemies, and reach the exit.

#### Acceptance Criteria

1. THE Dungeon SHALL be exactly 16 tiles wide and 16 tiles high
2. WHEN the player attempts to move outside the dungeon bounds, THE Game SHALL display "You cannot go that way" and prevent movement
3. THE Dungeon SHALL contain exactly one Exit tile
4. WHILE the player is alive, THE Game SHALL allow movement in four directions: up, down, left, and right
5. WHEN the player moves onto a tile containing an item, THE Game SHALL add the item to the player's inventory and replace the tile with floor

### Requirement 2: Turn-Based Combat

**User Story:** As a player, I want to engage in turn-based combat with enemies, so that I can defeat them and gain rewards.

#### Acceptance Criteria

1. WHEN the player moves onto a tile containing an enemy, THE Game SHALL initiate combat with that enemy
2. WHILE combat is active, THE Game SHALL alternate between player turns and enemy turns until one combatant is defeated
3. DURING the player's combat turn, THE Acolyte SHALL deal damage calculated as: base_attack + equipment_bonus + random(0,3)
4. DURING the enemy's combat turn, THE Enemy SHALL deal damage calculated as: base_attack - player_defense + random(0,1), with a minimum of 1 damage
5. IF the player's HP reaches 0 during combat, THE Game SHALL end the game with a defeat message

### Requirement 3: Enemy Special Abilities

**User Story:** As a player, I want to face enemies with unique special abilities, so that combat remains challenging and varied.

#### Acceptance Criteria

1. WHEN combat begins with an enemy that has a special ability, THE Game SHALL apply the ability during the enemy's turn
2. IF the enemy has the "lifesteal" ability, THE Enemy SHALL restore half the damage dealt to the player as HP
3. IF the enemy has the "berserk" ability, THE Enemy SHALL deal 50% more damage but take no damage from player attacks for one turn
4. IF the enemy has the "phase" ability, THE Enemy SHALL have a 30% chance to dodge all player attacks
5. IF the enemy has the "rebirth" ability, THE Enemy SHALL revive with 25% HP when defeated, once per combat

### Requirement 4: Skill Tree System

**User Story:** As a player, I want to upgrade skills using skill points, so that I can enhance my character's capabilities.

#### Acceptance Criteria

1. WHEN the player levels up, THE Game SHALL award 1 skill point
2. WHILE the player has skill points available, THE Game SHALL allow upgrading any of the 6 skill types
3. THE 6 skill types SHALL be: Critical Strike, Dodge, Treasure Hunter, Magic, Stealth, and Vitality
4. WHEN a skill is upgraded, THE Game SHALL apply the skill's bonus to the player's stats
5. IF the player attempts to upgrade a skill without sufficient skill points, THE Game SHALL display "Not enough skill points" and prevent the upgrade

### Requirement 5: Equipment System

**User Story:** As a player, I want to equip 8 different item slots, so that I can enhance my character's stats.

#### Acceptance Criteria

1. THE Equipment System SHALL provide exactly 8 slots: Sword, Shield, Boots, Amulet, Ring, Helm, Cape, and Gloves
2. WHEN an equipment item is picked up, THE Game SHALL add it to the inventory and apply its bonuses
3. IF the player attempts to equip an item they don't possess, THE Game SHALL display "Item not in inventory" and prevent equipping
4. WHEN an item is equipped, THE Game SHALL apply the item's stat bonuses to the player's current stats
5. WHEN an item is unequipped, THE Game SHALL remove the item's stat bonuses from the player's current stats

### Requirement 6: Save/Load Functionality

**User Story:** As a player, I want to save and load my game progress, so that I can continue later or try different approaches.

#### Acceptance Criteria

1. WHEN the player initiates a save, THE Game SHALL write the complete game state to a save file in the selected slot
2. THE Save System SHALL support at least 3 save slots
3. WHEN the player initiates a load, THE Game SHALL restore the game state from the selected save slot
4. IF the selected save slot contains no saved game, THE Game SHALL display "No save file in slot X" and prevent loading
5. FOR ALL valid game states, saving then loading SHALL restore the exact same game state (round-trip property)

### Requirement 7: Multiple Difficulty Levels

**User Story:** As a player, I want to select from multiple difficulty levels, so that I can choose an appropriate challenge.

#### Acceptance Criteria

1. WHERE the game starts, THE Game SHALL present 3 difficulty levels: Easy, Normal, and Hard
2. WHEN Easy difficulty is selected, THE Enemy Stats SHALL be reduced by 25%
3. WHEN Hard difficulty is selected, THE Enemy Stats SHALL be increased by 50%
4. WHILE playing, THE Difficulty Setting SHALL affect all enemy encounters consistently
5. IF the player attempts to change difficulty mid-game, THE Game SHALL display "Difficulty cannot be changed during gameplay"

### Requirement 8: Achievement System

**User Story:** As a player, I want to earn achievements for completing milestones, so that I can track my progress and accomplishments.

#### Acceptance Criteria

1. WHEN the player defeats their first enemy, THE Game SHALL award the "First Blood" achievement
2. WHEN the player reaches level 10, THE Game SHALL award the "Veteran" achievement
3. WHEN the player defeats the dragon enemy, THE Game SHALL award the "Dragon Slayer" achievement
4. WHEN the player collects 1000 gold, THE Game SHALL award the "Rich" achievement
5. WHERE achievements are earned, THE Game SHALL display a notification and add the achievement to the player's record

### Requirement 9: Player Movement and Tile Interactions

**User Story:** As a player, I want to move through the dungeon and interact with tiles, so that I can explore and collect items.

#### Acceptance Criteria

1. WHEN the player moves onto a wall tile, THE Game SHALL display "You hit a wall" and prevent movement
2. WHEN the player moves onto a door tile and possesses keys, THE Game SHALL consume 1 key, replace the door with floor, and display "Unlocked door with key!"
3. WHEN the player moves onto a door tile without keys, THE Game SHALL display "Locked! Find a key." and prevent movement
4. WHEN the player moves onto a gold tile, THE Game SHALL add random(10,30) gold to the player's inventory
5. WHEN the player moves onto a potion tile, THE Game SHALL add 1 health potion to the player's inventory

### Requirement 10: Level Progression

**User Story:** As a player, I want to level up by gaining experience points, so that my character grows stronger.

#### Acceptance Criteria

1. WHEN the player defeats an enemy, THE Game SHALL award experience points equal to the enemy's XP value
2. IF the player's XP reaches or exceeds the XP needed for the current level, THE Game SHALL level up the player
3. WHEN the player levels up, THE Game SHALL increase max HP by 5, attack by 2, and defense by 1
4. WHEN the player levels up, THE Game SHALL fully restore the player's HP
5. WHEN the player levels up, THE Game SHALL double the XP needed for the next level

### Requirement 11: Game Over Conditions

**User Story:** As a player, I want clear win and lose conditions, so that I understand when the game ends.

#### Acceptance Criteria

1. IF the player's HP reaches 0, THE Game SHALL end with a defeat screen displaying final stats
2. WHEN the player moves onto the exit tile, THE Game SHALL end with a victory screen displaying final stats
3. WHEN the game ends, THE Game SHALL display the player's final level, gold, and enemies defeated
4. WHEN the game ends, THE Game SHALL offer the option to return to the main menu or quit
5. IF the player chooses to quit, THE Game SHALL exit cleanly and restore the terminal cursor

### Requirement 12: Input Handling

**User Story:** As a player, I want responsive input handling, so that I can control the game effectively.

#### Acceptance Criteria

1. THE Game SHALL accept WASD keys for movement (W=up, S=down, A=left, D=right)
2. THE Game SHALL accept arrow keys for movement as an alternative to WASD
3. WHEN the player presses 'I', THE Game SHALL open the inventory menu
4. WHEN the player presses 'S', THE Game SHALL save to the current save slot
5. WHEN the player presses 'Q', THE Game SHALL quit to the main menu or exit

### Requirement 13: UI Rendering

**User Story:** As a player, I want a clear and informative UI, so that I can understand the game state at a glance.

#### Acceptance Criteria

1. THE Game SHALL display the dungeon map with appropriate symbols and colors for each tile type
2. THE Game SHALL display the player's current HP, attack, defense, level, and XP
3. THE Game SHALL display the player's current gold and inventory counts
4. WHEN the minimap is enabled, THE Game SHALL show a 16x16 overview of the dungeon
5. THE Game SHALL display a combat log showing recent actions and damage dealt

### Requirement 14: Error Handling

**User Story:** As a player, I want graceful error handling, so that the game remains stable during unexpected situations.

#### Acceptance Criteria

1. IF a save file is corrupted, THE Game SHALL display "Save file corrupted" and prevent loading
2. IF the player attempts an invalid action, THE Game SHALL display an appropriate error message
3. IF the terminal does not support required ANSI escape codes, THE Game SHALL display "Terminal incompatible" and exit gracefully
4. IF the save directory cannot be created, THE Game SHALL display "Cannot create save directory" and continue without save functionality
5. IF an unexpected error occurs, THE Game SHALL log the error and attempt to return to a stable state

### Requirement 15: Save File Format

**User Story:** As a developer, I want a structured save file format, so that game state can be reliably persisted and restored.

#### Acceptance Criteria

1. THE Save File SHALL use a key-value format with one parameter per line
2. THE Save File SHALL include all player state: position, HP, stats, inventory, equipment, and skills
3. THE Save File SHALL include the complete map state with all tile types
4. THE Save File SHALL include enemy positions and states
5. THE Save File SHALL include game metadata: difficulty, achievements, and current slot

### Requirement 16: Parser and Serializer

**User Story:** As a developer, I want reliable save file parsing and serialization, so that game state is preserved correctly.

#### Acceptance Criteria

1. WHEN a valid save file is provided, THE Parser SHALL parse it into a complete GameState object
2. WHEN an invalid save file is provided, THE Parser SHALL return a descriptive error message
3. THE Serializer SHALL format GameState objects back into valid save files
4. FOR ALL valid GameState objects, parsing then serializing then parsing SHALL produce an equivalent object (round-trip property)
5. THE Serializer SHALL use the same key-value format as specified in Requirement 15
