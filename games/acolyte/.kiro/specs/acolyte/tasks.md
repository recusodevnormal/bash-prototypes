# Implementation Plan: Acolyte - Bash Roguelike Game

## Overview

This implementation will create a terminal-based roguelike dungeon crawler in Bash. The game features a 16x16 dungeon, turn-based combat, skill trees, equipment management, save/load functionality, and an achievement system. Tasks are organized to build the game incrementally, starting with core infrastructure and progressing to full gameplay features.

## Tasks

- [-] 1. Set up project structure and core game state
  - Create directory structure for saves and game files
  - Initialize global variables for game state (player, map, enemies, inventory)
  - Set up associative arrays for player stats, skills, and equipment
  - _Requirements: 1.1, 1.4, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 12.1, 13.1, 15.1, 16.1_

- [ ] 2. Implement map generation and tile system
  - [ ] 2.1 Create tile type constants and grid array
    - Define TileType enum values (WALL, FLOOR, MONSTER, GOLD, POTION, KEY, DOOR, EXIT, items)
    - Initialize 16x16 grid with walls and floor tiles
    - _Requirements: 1.1, 9.1, 15.3_
  
  - [ ] 2.2 Implement map generation algorithm
    - Place exit at a random position
    - Add random items (gold, potions, keys, equipment)
    - Place enemies with appropriate types
    - _Requirements: 1.3, 1.5, 2.1, 9.4, 9.5_
  
  - [ ]* 2.3 Write property test for map generation
    - **Property 1: Player Position Bounds**
    - **Validates: Requirements 1.2, 9.1**
    - Ensure all generated maps have valid positions

- [ ] 3. Implement player movement and tile interactions
  - [ ] 3.1 Create movement functions
    - Implement move_player(dx, dy) function
    - Add bounds checking (0-15 range)
    - _Requirements: 1.2, 9.1_
  
  - [ ] 3.2 Implement wall collision handling
    - Display "You hit a wall" message
    - Prevent movement into walls
    - _Requirements: 9.1_
  
  - [ ] 3.3 Implement door interaction
    - Check for keys in inventory
    - Consume key and replace door with floor
    - Display appropriate messages
    - _Requirements: 9.2, 9.3_
  
  - [ ] 3.4 Implement item pickup
    - Add gold to inventory (random 10-30)
    - Add potions, keys, and equipment to inventory
    - Replace tile with floor
    - _Requirements: 1.5, 9.4, 9.5_

- [ ] 4. Implement combat system
  - [ ] 4.1 Create combat state management
    - Initialize combat variables (player HP, enemy HP)
    - Set up combat loop structure
    - _Requirements: 2.1, 2.2_
  
  - [ ] 4.2 Implement player turn damage calculation
    - Calculate damage: base_attack + equipment_bonus + random(0,3)
    - Check for critical hits (skill-based)
    - Apply damage to enemy
    - _Requirements: 2.3, 4.4_
  
  - [ ] 4.3 Implement enemy turn damage calculation
    - Calculate damage: base_attack - player_defense + random(0,1)
    - Ensure minimum 1 damage
    - Apply damage to player
    - _Requirements: 2.4, 4.4_
  
  - [ ] 4.4 Implement enemy special abilities
    - Lifesteal: restore half damage dealt
    - Berserk: 50% more damage, no damage taken for one turn
    - Phase: 30% chance to dodge attacks
    - Rebirth: revive with 25% HP when defeated
    - _Requirements: 3.2, 3.3, 3.4, 3.5_
  
  - [ ]* 4.5 Write property test for combat fairness
    - **Property 4: Combat Fairness**
    - **Validates: Requirements 2.3, 2.4, 3.1**
    - Verify damage calculations within expected ranges

- [ ] 5. Implement skill tree system
  - [ ] 5.1 Create skill type constants and skill tree structure
    - Define 6 skill types (Critical Strike, Dodge, Treasure Hunter, Magic, Stealth, Vitality)
    - Initialize skill points to 0
    - _Requirements: 4.3_
  
  - [ ] 5.2 Implement skill upgrade function
    - Check for available skill points
    - Increment skill level
    - Apply stat bonuses
    - _Requirements: 4.2, 4.4, 4.5_
  
  - [ ] 5.3 Implement skill point award on level up
    - Award 1 skill point when player levels up
    - Display skill point notification
    - _Requirements: 4.1_
  
  - [ ]* 5.4 Write unit tests for skill upgrades
    - Test skill point consumption
    - Test bonus application
    - Test error when insufficient points
    - _Requirements: 4.5_

- [ ] 6. Implement equipment system
  - [ ] 6.1 Create equipment slot constants
    - Define 8 slots: Sword, Shield, Boots, Amulet, Ring, Helm, Cape, Gloves
    - Initialize equipment slots as false (unequipped)
    - _Requirements: 5.1_
  
  - [ ] 6.2 Implement equipment application
    - Apply stat bonuses when item equipped
    - Update player stats (attack, defense, max_hp)
    - _Requirements: 5.2, 5.4_
  
  - [ ] 6.3 Implement equipment removal
    - Remove stat bonuses when item unequipped
    - Restore player stats
    - _Requirements: 5.5_
  
  - [ ]* 6.4 Write unit tests for equipment system
    - Test bonus application
    - Test bonus removal
    - Test error when equipping missing item
    - _Requirements: 5.3, 5.4, 5.5_

- [ ] 7. Implement save/load functionality
  - [ ] 7.1 Create save directory and file structure
    - Create ~/.acolyte_saves directory
    - Implement save file naming (save_{slot}.dat)
    - _Requirements: 6.2_
  
  - [ ] 7.2 Implement save file serialization
    - Write all player state variables
    - Write map grid state
    - Write enemy positions and states
    - Write inventory and equipment
    - _Requirements: 6.1, 15.1, 15.2, 15.3, 15.4, 15.5_
  
  - [ ] 7.3 Implement save file parsing
    - Read key-value pairs from save file
    - Parse player state, map, enemies, inventory
    - Handle missing or corrupted files
    - _Requirements: 6.3, 6.4, 16.1, 16.2_
  
  - [ ]* 7.4 Write property test for save/load consistency
    - **Property 5: Save/Load Consistency**
    - **Validates: Requirements 6.5**
    - Verify round-trip state preservation

- [ ] 8. Implement difficulty levels
  - [ ] 8.1 Create difficulty constants
    - Define Easy, Normal, Hard levels
    - Set multiplier values (0.75, 1.0, 1.5)
    - _Requirements: 7.1_
  
  - [ ] 8.2 Implement difficulty-based enemy stats
    - Apply multipliers to enemy HP, attack, defense
    - Store difficulty in game state
    - _Requirements: 7.2, 7.3, 7.4_
  
  - [ ] 8.3 Implement difficulty change prevention
    - Check difficulty before allowing changes
    - Display error message if mid-game
    - _Requirements: 7.5_
  
  - [ ]* 8.4 Write unit tests for difficulty multipliers
    - Test Easy difficulty stats reduction
    - Test Hard difficulty stats increase
    - Test mid-game difficulty change prevention
    - _Requirements: 7.2, 7.3, 7.4, 7.5_

- [ ] 9. Implement achievement system
  - [ ] 9.1 Create achievement constants
    - Define achievements: First Blood, Veteran, Dragon Slayer, Rich
    - Initialize achievements array
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  
  - [ ] 9.2 Implement achievement checking logic
    - Check for first enemy defeat
    - Check for level 10
    - Check for dragon defeat
    - Check for 1000 gold
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  
  - [ ] 9.3 Implement achievement notification
    - Display achievement message
    - Add to achievements list
    - _Requirements: 8.5_
  
  - [ ]* 9.4 Write unit tests for achievement triggers
    - Test First Blood achievement
    - Test Veteran achievement
    - Test Dragon Slayer achievement
    - Test Rich achievement
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 10. Implement level progression
  - [ ] 10.1 Create XP progression constants
    - Define base XP needed (50)
    - Implement doubling on level up
    - _Requirements: 10.5_
  
  - [ ] 10.2 Implement XP gain function
    - Award XP from enemy defeat
    - Apply amulet bonus (10%)
    - _Requirements: 10.1_
  
  - [ ] 10.3 Implement level up logic
    - Check XP threshold
    - Increase level, stats, and max HP
    - Fully restore HP
    - Award skill points
    - _Requirements: 10.2, 10.3, 10.4_
  
  - [ ]* 10.4 Write property test for XP progression
    - **Property 3: XP Progression**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**
    - Verify XP values and level progression

- [ ] 11. Implement game over conditions
  - [ ] 11.1 Implement defeat screen
    - Display defeat message
    - Show final stats (level, gold, enemies defeated)
    - _Requirements: 11.1, 11.3_
  
  - [ ] 11.2 Implement victory screen
    - Display victory message
    - Show final stats
    - _Requirements: 11.2, 11.3_
  
  - [ ] 11.3 Implement game over menu
    - Offer return to main menu or quit option
    - Handle user choice
    - _Requirements: 11.4, 11.5_
  
  - [ ]* 11.4 Write unit tests for game over conditions
    - Test defeat screen display
    - Test victory screen display
    - Test menu options
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [ ] 12. Implement input handling
  - [ ] 12.1 Create input key constants
    - Define keys: MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT
    - Define INVENTORY, SAVE, LOAD, QUIT
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_
  
  - [ ] 12.2 Implement WASD and arrow key parsing
    - Map W/A/S/D to movement
    - Map arrow keys to movement
    - _Requirements: 12.1, 12.2_
  
  - [ ] 12.3 Implement menu key handling
    - I: Open inventory
    - S: Save game
    - Q: Quit
    - _Requirements: 12.3, 12.4, 12.5_
  
  - [ ]* 12.4 Write unit tests for input parsing
    - Test WASD key mapping
    - Test arrow key mapping
    - Test menu key handling
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [ ] 13. Implement UI rendering
  - [ ] 13.1 Create ANSI escape code utilities
    - Implement clear screen
    - Implement cursor control
    - Implement color codes
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ] 13.2 Implement map rendering
    - Draw 16x16 grid with appropriate symbols
    - Apply colors for tile types
    - _Requirements: 13.1_
  
  - [ ] 13.3 Implement status bar rendering
    - Display HP, attack, defense, level, XP
    - Display gold and inventory counts
    - _Requirements: 13.2, 13.3_
  
  - [ ] 13.4 Implement combat log
    - Track recent actions
    - Display damage dealt and received
    - _Requirements: 13.5_
  
  - [ ]* 13.5 Write unit tests for UI rendering
    - Test map rendering
    - Test status bar rendering
    - Test color codes
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [ ] 14. Implement error handling
  - [ ] 14.1 Implement save file validation
    - Check file format
    - Validate required fields
    - _Requirements: 14.1, 16.2_
  
  - [ ] 14.2 Implement input validation
    - Handle invalid actions
    - Display appropriate error messages
    - _Requirements: 14.2_
  
  - [ ] 14.3 Implement terminal compatibility check
    - Test ANSI escape code support
    - Exit gracefully if incompatible
    - _Requirements: 14.3_
  
  - [ ] 14.4 Implement save directory creation
    - Create directory if missing
    - Handle creation failures
    - _Requirements: 14.4_
  
  - [ ]* 14.5 Write unit tests for error handling
    - Test corrupted save file handling
    - Test invalid input handling
    - Test directory creation failure
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [ ] 15. Implement main game loop
  - [ ] 15.1 Create game initialization
    - Initialize all game state
    - Show intro screen
    - _Requirements: 1.1, 7.1, 11.5_
  
  - [ ] 15.2 Implement main loop structure
    - Render UI
    - Read input
    - Process input
    - Check game over
    - _Requirements: 1.4, 2.2, 12.1, 13.1_
  
  - [ ] 15.3 Implement game cleanup
    - Restore terminal cursor
    - Clear screen
    - Exit cleanly
    - _Requirements: 11.5_
  
  - [ ]* 15.4 Write integration tests for main loop
    - Test complete game flow
    - Test win condition
    - Test lose condition
    - _Requirements: 1.1, 1.4, 2.1, 2.2, 11.1, 11.2, 12.1, 13.1_

- [ ] 16. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The game will be implemented entirely in Bash as specified in the requirements