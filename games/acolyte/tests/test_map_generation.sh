#!/usr/bin/env bash
# Property-based test for map generation
# Validates: Requirements 1.2, 9.1
# Property 1: Player Position Bounds
# Ensure all generated maps have valid positions

set -e

# Source the game to get access to functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../acolyte.sh"

# Test constants
TEST_RUNS=100
MAP_WIDTH=16
MAP_HEIGHT=16
PLAYER_START_X=2
PLAYER_START_Y=2

# Track test results
failed_tests=0
passed_tests=0

# Test helper: Check if position is within bounds
is_position_valid() {
    local x=$1
    local y=$2
    
    # Player position must be within 0-15 range
    if [ $x -lt 0 ] || [ $x -ge $MAP_WIDTH ]; then
        return 1
    fi
    
    if [ $y -lt 0 ] || [ $y -ge $MAP_HEIGHT ]; then
        return 1
    fi
    
    return 0
}

# Test 1: Player start position is valid
test_player_start_position() {
    echo "Test 1: Player start position is within bounds"
    
    # Reset and generate map
    init_game_state
    
    # Check player position
    if is_position_valid $player_x $player_y; then
        echo "  PASS: Player position ($player_x, $player_y) is valid"
        ((passed_tests++))
    else
        echo "  FAIL: Player position ($player_x, $player_y) is out of bounds"
        ((failed_tests++))
    fi
}

# Test 2: Exit position is valid after map generation
test_exit_position() {
    echo "Test 2: Exit position is within bounds"
    
    # Reset and generate map
    init_game_state
    
    if is_position_valid $exit_x $exit_y; then
        echo "  PASS: Exit position ($exit_x, $exit_y) is valid"
        ((passed_tests++))
    else
        echo "  FAIL: Exit position ($exit_x, $exit_y) is out of bounds"
        ((failed_tests++))
    fi
}

# Test 3: All item positions are valid after map generation
test_item_positions() {
    echo "Test 3: All item positions are within bounds"
    
    # Reset and generate map
    init_game_state
    
    local invalid_items=0
    
    # Check each tile for items
    for ((y=0; y<MAP_HEIGHT; y++)); do
        for ((x=0; x<MAP_WIDTH; x++)); do
            local tile=$(get_tile $x $y)
            
            # Check if tile is an item type
            case "$tile" in
                "G"|"H"|"K"|"S"|"P"|"B"|"A"|"R"|"L"|"C"|"V"|"?")
                    if ! is_position_valid $x $y; then
                        echo "  FAIL: Item at ($x, $y) is out of bounds"
                        ((invalid_items++))
                    fi
                    ;;
            esac
        done
    done
    
    if [ $invalid_items -eq 0 ]; then
        echo "  PASS: All item positions are valid"
        ((passed_tests++))
    else
        ((failed_tests += invalid_items))
    fi
}

# Test 4: All enemy positions are valid after map generation
test_enemy_positions() {
    echo "Test 4: All enemy positions are within bounds"
    
    # Reset and generate map
    init_game_state
    
    local invalid_enemies=0
    
    # Check each enemy position
    for key in "${!enemies[@]}"; do
        # Parse position from key (format: "x_y")
        local x=${key%%_*}
        local y=${key##*_}
        
        if ! is_position_valid $x $y; then
            echo "  FAIL: Enemy at ($x, $y) is out of bounds"
            ((invalid_enemies++))
        fi
    done
    
    if [ $invalid_enemies -eq 0 ]; then
        echo "  PASS: All enemy positions are valid"
        ((passed_tests++))
    else
        ((failed_tests += invalid_enemies))
    fi
}

# Test 5: Multiple map generations all have valid positions
test_multiple_generations() {
    echo "Test 5: Multiple map generations have valid positions"
    
    local generation_failures=0
    
    for ((i=0; i<TEST_RUNS; i++)); do
        # Reset and generate map
        init_game_state
        
        # Check all positions
        if ! is_position_valid $player_x $player_y; then
            echo "  FAIL: Generation $i - Player position ($player_x, $player_y) is invalid"
            ((generation_failures++))
            continue
        fi
        
        if ! is_position_valid $exit_x $exit_y; then
            echo "  FAIL: Generation $i - Exit position ($exit_x, $exit_y) is invalid"
            ((generation_failures++))
            continue
        fi
        
        # Check items
        local items_valid=true
        for ((y=0; y<MAP_HEIGHT; y++)); do
            for ((x=0; x<MAP_WIDTH; x++)); do
                local tile=$(get_tile $x $y)
                case "$tile" in
                    "G"|"H"|"K"|"S"|"P"|"B"|"A"|"R"|"L"|"C"|"V"|"?")
                        if ! is_position_valid $x $y; then
                            items_valid=false
                            break 2
                        fi
                        ;;
                esac
            done
        done
        
        if [ "$items_valid" = "false" ]; then
            echo "  FAIL: Generation $i - Item position is invalid"
            ((generation_failures++))
            continue
        fi
        
        # Check enemies
        local enemies_valid=true
        for key in "${!enemies[@]}"; do
            local x=${key%%_*}
            local y=${key##*_}
            if ! is_position_valid $x $y; then
                enemies_valid=false
                break
            fi
        done
        
        if [ "$enemies_valid" = "false" ]; then
            echo "  FAIL: Generation $i - Enemy position is invalid"
            ((generation_failures++))
            continue
        fi
    done
    
    if [ $generation_failures -eq 0 ]; then
        echo "  PASS: All $TEST_RUNS generations had valid positions"
        ((passed_tests++))
    else
        echo "  FAIL: $generation_failures out of $TEST_RUNS generations had invalid positions"
        ((failed_tests += generation_failures))
    fi
}

# Run all tests
echo "=========================================="
echo "Map Generation Property Tests"
echo "Validates: Requirements 1.2, 9.1"
echo "Property: Player Position Bounds"
echo "=========================================="
echo ""

test_player_start_position
test_exit_position
test_item_positions
test_enemy_positions
test_multiple_generations

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo ""

if [ $failed_tests -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
