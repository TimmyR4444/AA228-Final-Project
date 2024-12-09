using Random
using Statistics

num_decks = 5                                       # Number of decks used
total_cards = num_decks * 52
shuffle_ratio = 0.1                                 # What percentage of cards are left before shuffling
cards_left_shuffle = shuffle_ratio * total_cards    # Cards left when it's time to shuffle

num_hands_simulate = 1
discount = 0.9
num_simulations = 1000                             # Number of simulations per action

total_hands = 1e5
actions = ["stand","hit","double"]

# Define a basic game state structure for blackjack
struct GameState
    player_hand::Vector{Int}   # Player's cards
    dealer_hand::Vector{Int}   # Dealer's cards
    is_terminal::Bool          # Whether the round is over
    reward::Float64            # Reward (1 win, -1 loss, 0 tie)
    deck::Vector{Int}          # Cards left in the deck
end

# Compute the sum of a hand, handling aces (1 or 11) carefully
function hand_value(hand::Vector{Int})
    total = sum(hand)
    aces = count(x -> x == 11, hand)
    while total > 21 && aces > 0
        total -= 10
        aces -= 1
    end
    return total
end

# Check if a hand is bust
function is_bust(hand::Vector{Int})
    return hand_value(hand) > 21
end

# Simulate drawing a random card
function draw_card(deck::Vector{Int})
    index_remove = rand(1:length(deck))
    card = deck[index_remove]
    card_value = card
    if card > 11
        card_value = 10                 # All face cards are 10
    end
    deleteat!(deck, index_remove)       # Remove card from deck
    
    return [card_value, deck]
end

# Initialize a new game state
function new_game()
    deck = sort((repeat(2:14, 4*num_decks)))
    player_card_1, deck = draw_card(deck)
    player_card_2, deck = draw_card(deck)
    dealer_card, deck = draw_card(deck)
    
    player_hand = [player_card_1, player_card_2]
    dealer_hand = [dealer_card]

    # Blackjack
    if hand_value(player_hand) == 21
        dealer_card2, deck = draw_card(deck)
        push!(dealer_hand, dealer_card2)
        return GameState(sort(player_hand), sort(dealer_hand), true, 1.5, deck)
    else
        return GameState(sort(player_hand), sort(dealer_hand), false, 0.0, deck)
    end
end

# Start a new hand
function new_hand(deck)
    player_card_1, deck = draw_card(deck)
    player_card_2, deck = draw_card(deck)
    dealer_card, deck = draw_card(deck)
    
    player_hand = [player_card_1, player_card_2]
    dealer_hand = [dealer_card]

    # Blackjack
    if hand_value(player_hand) == 21
        dealer_card2, deck = draw_card(deck)
        push!(dealer_hand, dealer_card2)
        return GameState(sort(player_hand), sort(dealer_hand), true, 1.5, deck)
    else
        return GameState(sort(player_hand), sort(dealer_hand), false, 0.0, deck)
    end
end

# Take an action and return the new game state
function take_action(state::GameState, action::String)
    player_hand = copy(state.player_hand)
    dealer_hand = copy(state.dealer_hand)
    deck = copy(state.deck)
    if action == "hit"
        hit_deck = deck
        hit_card, hit_deck = draw_card(deck)
        push!(player_hand, hit_card)
        if is_bust(player_hand)
            return GameState(sort(player_hand), sort(dealer_hand), true, -1.0, hit_deck)
        else
            return GameState(sort(player_hand), sort(dealer_hand), false, 0.0, hit_deck)
        end
    elseif action == "stand"
        stand_deck = deck
        # Dealer's turn
        while hand_value(dealer_hand) < 17
            dealer_hit_card, stand_deck = draw_card(stand_deck)
            push!(dealer_hand, dealer_hit_card)
        end
        player_value = hand_value(player_hand)
        dealer_value = hand_value(dealer_hand)
        if is_bust(dealer_hand) || player_value > dealer_value
            return GameState(sort(player_hand), sort(dealer_hand), true, 1.0, stand_deck)
        elseif player_value < dealer_value
            return GameState(sort(player_hand), sort(dealer_hand), true, -1.0, stand_deck)
        else
            return GameState(sort(player_hand), sort(dealer_hand), true, 0.0, stand_deck)
        end
    elseif action == "double"
        double_deck = deck
        double_card, double_deck = draw_card(double_deck)
        push!(player_hand, double_card)
        if is_bust(player_hand)
            return GameState(sort(player_hand), sort(dealer_hand), true, -2.0, double_deck)
        end
        # Dealer's turn
        while hand_value(dealer_hand) < 17
            dealer_hit_card, double_deck = draw_card(double_deck)
            push!(dealer_hand, dealer_hit_card)
        end
        player_value = hand_value(player_hand)
        dealer_value = hand_value(dealer_hand)
        if is_bust(dealer_hand) || player_value > dealer_value
            return GameState(sort(player_hand), sort(dealer_hand), true, 2.0, double_deck)
        elseif player_value < dealer_value
            return GameState(sort(player_hand), sort(dealer_hand), true, -2.0, double_deck)
        else
            return GameState(sort(player_hand), sort(dealer_hand), true, 0.0, double_deck)
        end
    end
end

# Blackjack strategy action
function blackjack_strategy(state::GameState)
    player_hand = state.player_hand
    dealer_hand = state.dealer_hand

    player_total = hand_value(player_hand)
    dealer_total = hand_value(dealer_hand)
        
    num_aces = count(x -> x == 11, player_hand)
        
    if length(player_hand) == 2
        if player_total == 11 && dealer_total <= 10
            return "double"
        elseif num_aces == 1 && dealer_total >= 5 && dealer_total <= 6 && player_total <= 18 && player_total >= 13
            return "double"
        elseif num_aces == 1 && dealer_total == 4 && player_total <= 18 && player_total >= 15
            return "double"
        elseif num_aces == 1 && dealer_total == 3 && player_total <= 18 && player_total >= 17
            return "double"
        elseif player_total == 10 && dealer_total <= 9
            return "double"
        elseif player_total == 9 && dealer_total >= 3 && dealer_total <= 6
            return "double"
        end
    end
        
    if num_aces == 1
        if player_total >= 19
            return "stand"
        elseif player_total == 18 && dealer_total <= 8
            return "stand"
        else
            return "hit"
        end
    end

    if player_total >= 17
        return "stand"
    elseif player_total >= 13 && player_total <= 16 && dealer_total <= 6
        return "stand"
    elseif player_total == 12 && dealer_total >= 4 && dealer_total <= 6
        return "stand"
    else
        return "hit"
    end
end

# Basic actor
function basic(state)
    player_hand = state.player_hand
    player_total = hand_value(player_hand)

    if player_total < 17
        return "hit"
    else
        return "stand"
    end
end

# Lookahead actor
function lookahead_actor(state::GameState)
    # Initialize reward collections
    action_rewards = Dict(action => [] for action in actions)
    
    original_state = state
    # Iterate over actions
    for action in actions
        for _ in 1:num_simulations
            state = take_action(original_state, action)  # Take the initial action
            num_completed_hands = 0
            reward = 0

            # Simulate subsequent actions
            while num_completed_hands < num_hands_simulate
                while !state.is_terminal
                    random_action = blackjack_strategy(state)                   # Choose next action
                    state = take_action(state, random_action)
                end
                reward += state.reward * (discount^(num_completed_hands))        # Discount reward
                num_completed_hands += 1
                
                curr_deck = state.deck
                state = new_hand(curr_deck)
            end
            push!(action_rewards[action], reward)  # Store reward
        end
    end

    # Compute mean rewards
    mean_rewards = Dict(action => mean(rewards) for (action, rewards) in action_rewards)

    # Return action with the highest mean reward
    best_action = argmax(mean_rewards)  # Finds the key with the maximum value
    return best_action
end

# Simulate blackjack game
function lets_play()
    # Start of the game
    deck = sort((repeat(2:14, 4*num_decks)))
    state = new_hand(deck)
    number_hands = 0
    total_reward = 0

    # Track how our actor compares to blackjack strategy
    total_actions = 0
    same_action = 0
    cards_left = 0
    diff_action = 0

    while number_hands < total_hands
        if length(deck) < cards_left_shuffle
            deck = sort((repeat(2:14, 4*num_decks)))
        end

        state = new_hand(deck)
        while !state.is_terminal
            action = lookahead_actor(state)
            # action = blackjack_strategy(state)
            # action = basic(state)
            strat_action = blackjack_strategy(state)
            
            # See how similar our actor is to the blackjack strategy
            total_actions += 1
            if action == strat_action
                same_action += 1
            else
                cards_left += length(state.deck)
                diff_action += 1
            end
            state = take_action(state, action)
        end
        total_reward += state.reward
        number_hands += 1
        deck = state.deck
    end
    println(same_action/total_actions)
    println(cards_left / (diff_action * total_cards))
    return total_reward / total_hands
end

println(lets_play())