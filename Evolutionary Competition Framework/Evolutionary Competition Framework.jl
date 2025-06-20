#### THRESHOLD SPATIAL EVOLUTIONARY STAGE GAME MODEL
# This model takes the original spatial evolutionary stage game model
# and instead of lowest-performing agent dying off in a neighborhood,
# all cells below some threshold die off.This happens asynchronously,
# so that we do not end up with empty fields.
#
# In addition, instead of using the neighbor with max score, we use
# a random neighbor to replace the cell. This takes away the pressure to
# be the best, and instead rewards any survival above the threshold.

#### 1. SETUP VARIABLES AND CONFIGURATIONS ####
## 1.1 PACKAGES USED

using Agents                # needed to create the ABM model
using Random                # used to generate random numbers
using InteractiveDynamics   # used to generate abm_data_exploration, the interactive simulation
using GLMakie               # used to render the interactive simulation
using CairoMakie            # used to output video
using OrderedCollections    # used to generate a dictionary that preserves internal order

## 1.2 DEFINING AGENTS

mutable struct GroupAgent <: AbstractAgent
    id::Int                 # The internal model identifier number of the agent
    pos::NTuple{2,Int}      # The x, y location of the agent on a 2D grid
    uid::Int                # the unique ID used for every new born agent
    strategy::String        # strategy used by the agent
    score::Float32          # used to keep score during interactions between agents
    choice::Int             # 0 is defect, 1 is cooperate
    hitlist::Vector{Int}    # used to store uid of agents against which to defect next round
    goodlist::Vector{Int}   # used to store uid of agents with which to cooperate next round
end

## 1.3 PARAMETERS

# You can use the following values for parameters to simulate stage games:

# Hawk and Dove
#=
defect_multiplier = 4
coop_multiplier = 2
sucker_multiplier = 0
punishment_multiplier = -4
=#

#Prisoner's Dilemma
#=
defect_multiplier = 1.5
coop_multiplier = 1
sucker_multiplier = 0
punishment_multiplier = 0.3
=#

## 1.4 INITIALIZING GRIDSPACE

# This function creates the ABM, populates starting paremeters and sets up agents
function initialize(; numagents = 2500,
    griddims = (50, 50),
    agent_id = 0,
    step = 0,
    threshold = 5,
    # we need to pass the default payoff matrix values to the function
    defect_multiplier = 1.9,
    coop_multiplier = 1,
    sucker_multiplier = 0,
    punishment_multiplier = 0.3,
    # we also need to pass the strategies that will be used in the simulation
    coop_strategy = 1,      # 0 means not selected, 1 is selected
    defect_strategy = 1,
    random_strategy = 1,
    tft_strategy = 1,
    pavlov_strategy = 1,
    cd_strategy = 0,
    cr_strategy = 0,
    rd_strategy = 0,
    )
    ## 1.4.1 CREATE THE MODEL
    # the properties dictionary is needed to pass the values from the function to the model
    properties = Dict(
    :numagents => numagents,
    :agent_id => agent_id,
    :step => step,
    :threshold => threshold,
    :defect_multiplier => defect_multiplier,
    :coop_multiplier => coop_multiplier,
    :sucker_multiplier => sucker_multiplier,
    :punishment_multiplier => punishment_multiplier,
    :coop_strategy => coop_strategy,
    :defect_strategy => defect_strategy,
    :random_strategy => random_strategy,
    :tft_strategy => tft_strategy,
    :pavlov_strategy => pavlov_strategy,
    :cd_strategy => cd_strategy,
    :cr_strategy => cr_strategy,
    :rd_strategy => rd_strategy,
    )
    # define the grid space (square grid, horizontal and vertical wrap)
    space = GridSpace(griddims, periodic = true)
    # default random number generator
    rng = Random.default_rng()

    # create the model with the defined properties
    model = ABM(GroupAgent, space; properties, rng, scheduler = Schedulers.randomly)

    ## 1.4.2 ADDING AGENTS
    # create numagents number of agents in our model and move them to a random empty spot
    for n = 1:numagents
        model.agent_id = n
        agent = GroupAgent(n, (1, 1), model.agent_id, "", 0.0, 0, [], []) # setup blank agents
        add_agent_single!(agent, model) # move agent to an unoccupied spot in the model
    end

    ## 1.4.3 PREPOPULATE MODEL
    # run the interact! function once to prepopulate scores for the first step
    for agent in allagents(model)
        interact!(agent, model)
    end

    return model
end

#### 2. SETUP FUNCTIONS FOR RUNNING THE MODEL ####
## 2.1 DEFINING A STEP - CALLS OTHER FUNCTIONS

    ## 2.1.1 OVERALL MODEL STEP
function model_step!(model)
    # If this is the first step, we need to reset the agents with selected values/strategies.
    # This needs to happen to populate agent strategies based on the sliders in the interactive tool.
    # Currently, reset action in the interactive tool will not reinitialize the model with new values,
    # so we do it on the first step of our simulation instead.
    if model.step == 0
        # create a set of strategies to choose. Start with an empty vector
        select_strategy = []
        # For each selected strategy (if it was set to 1), add it to the vector of strategies
        if model.coop_strategy == 1
            push!(select_strategy, "coop")
        end
        if model.defect_strategy == 1
            push!(select_strategy, "defect")
        end
        if model.random_strategy == 1
            push!(select_strategy, "random")
        end
        if model.tft_strategy == 1
            push!(select_strategy, "tft")
        end
        if model.pavlov_strategy == 1
            push!(select_strategy, "pavlov")
        end
        if model.cd_strategy == 1
            push!(select_strategy, "cd")
        end
        if model.cr_strategy == 1
            push!(select_strategy, "cr")
        end
        if model.rd_strategy == 1
            push!(select_strategy, "rd")
        end
        # for each agent, set their strategy and reset values
        for n = 1:model.numagents
            # randomly select strategy from the strategy values vector
            model[n].strategy = select_strategy[rand(1:length(select_strategy))]
            # reset memory and the score for the agents. Choice does not need to be reset
            model[n].hitlist = []
            model[n].goodlist = []
            model[n].score = 0.0
            # recalculate each agent's score based on their new strategy
            interact!(model[n], model)
        end
    # if this is not the first step, run agent_step! for each agent
    else
        for agent in allagents(model)
            agent_step!(agent, model)
        end
    end
    # increment step counter to keep track of how many steps took place.
    # model.step will get reset to 0 when we click reset in the interactive tool.
    model.step += 1
end

    ## 2.1.2 STEP PERFORMED FOR EACH AGENT DURING EACH MODEL STEP
function agent_step!(agent, model)
    # interact with other agents to determine my score
    interact!(agent, model)

    # setup placeholder values so we can determine min and max
    max_value = -100.0
    min_value = 100.0
    temp_ID = -1
    temp_strategy = ""
    temp_hitlist = []
    temp_goodlist = []
    # Added "collect" function to turn nearby_agents collection into an array
    # Used the shuffle function to randomly sort the array afterwards


    # replace worst performing agents with best performing neighbor
    if agent.score < model.threshold  # if agent's score is the lower than needed to survive
        # reset the agent, give it a new ID and increment the ID counter
        for neighbor in shuffle!(collect(nearby_agents(agent, model)))
            if neighbor.uid != agent.uid
                    temp_strategy = neighbor.strategy
                    # we need to use deepcopy to duplicate the vector for our new agent
                    temp_hitlist = deepcopy(neighbor.hitlist)
                    temp_goodlist = deepcopy(neighbor.goodlist)
            end
        end # repeat for all neighbors
        agent.strategy = temp_strategy
        agent.hitlist = temp_hitlist
        agent.goodlist = temp_goodlist
        agent.uid = model.agent_id
        model.agent_id += 1
        interact!(agent, model) # recalculate the score with the new strategy
    end
    return
end

## 2.2 DEFINING INTERACTION BETWEEN AGENTS

function interact!(agent, model)
    agent.score = 0 # reset the score
    for neighbor in nearby_agents(agent, model)
        if neighbor.uid != agent.uid # only run for agents other than myself
            select_choice!(neighbor, agent) # define the choice of my neighbor
            select_choice!(agent, neighbor) # define my choice
            # increment my score based on our choices. Choice 1 is cooperate, 0 is defect
            if neighbor.choice == 1
                if agent.choice == 1
                    # the multipliers are part of the model, thus are called as model property
                    agent.score = agent.score + model.coop_multiplier
                elseif agent.choice == 0
                    agent.score = agent.score + model.defect_multiplier
                end
            elseif neighbor.choice == 0
                if agent.choice == 1
                    agent.score = agent.score + model.sucker_multiplier
                elseif agent.choice == 0
                    agent.score = agent.score + model.punishment_multiplier
                end
            end
            # update agent's memory
            if agent.strategy == "tft" || agent.strategy == "pavlov"
                update_hitlist!(agent, neighbor)
            end
            # update neighbor's memory
            if neighbor.strategy == "tft" || neighbor.strategy == "pavlov"
                update_hitlist!(neighbor, agent)
            end
        end
    end

    return
end

## 2.3 SELECTING A CHOICE

function select_choice!(agent, neighbor)
    # for each type of strategy, generate an appropriate choice
    # 1 is cooperate, 0 is defect
    if agent.strategy == "coop"
        agent.choice = 1
    elseif agent.strategy == "defect"
        agent.choice = 0
    elseif agent.strategy == "random"
        agent.choice = rand(0:1) # pick either 1 or 0, randomly
    elseif agent.strategy == "tft"
        if neighbor.uid in agent.hitlist
            agent.choice = 0 # defect if neighbor was in my bad list
        else
            agent.choice = 1 # otherwise, cooperate
        end
    elseif agent.strategy == "pavlov"
        if neighbor.uid in agent.hitlist
            agent.choice = 0 # defect if neighbor was in my bad list
        elseif neighbor.uid in agent.goodlist
            agent.choice = 1 # if they are in a good list, cooperate
        else
            agent.choice = rand(0:1) # otherwise, select a random choice
            #agent.choice = 1 # this was the original configuration for Pavlov
        end
    elseif agent.strategy == "cd"
        # if neighbor is part of my strategy group, cooperate. Otherwise, defect.
        if neighbor.strategy == "cd"
            agent.choice = 1
        else
            agent.choice = 0
        end
    elseif agent.strategy == "cr"
        # if neighbor is part of my strategy group, cooperate. Otherwise, pick a random choice.
        if neighbor.strategy == "cr"
            agent.choice = 1
        else
            agent.choice = rand(0:1)
        end
    elseif agent.strategy == "rd"
        # if neighbor is part of my strategy group, pick a random choice. Otherwise, defect.
        if neighbor.strategy == "rd"
            agent.choice = rand(0:1)
        else
            agent.choice = 0
        end
    end
    return
end


## 2.4 UPDATE HITLIST FOR TFT/PAVLOV

function update_hitlist!(agent, neighbor)
    # only update the memory lists of Pavlov and Tit For Tat - can be expanded in the future
    if agent.strategy == "tft"
        if neighbor.choice == 0
            if neighbor.uid ∉ agent.hitlist
                if length(agent.hitlist) < 150 # can be increased. Based on Dunbar's number
                    push!(agent.hitlist, neighbor.uid) # add an entry at the end
                else
                    deleteat!(agent.hitlist, 1) # remove first entry
                    push!(agent.hitlist, neighbor.uid) # add an entry at the end
                end
            end
        elseif neighbor.choice == 1
            filter!(x -> !(x == neighbor.uid), agent.hitlist) # remove the agent from the memory
        end
    elseif agent.strategy == "pavlov"
            if neighbor.choice == 0
                if agent.choice == 1
                    filter!(x -> !(x == neighbor.uid), agent.goodlist) # remove the agent from the memory
                    if neighbor.uid ∉ agent.hitlist
                        if length(agent.hitlist) < 150 # can be increased
                            push!(agent.hitlist, neighbor.uid) # add an entry at the end
                        else
                            deleteat!(agent.hitlist, 1) # remove first entry
                            push!(agent.hitlist, neighbor.uid) # add an entry at the end
                        end
                    end
                elseif agent.choice == 0
                    filter!(x -> !(x == neighbor.uid), agent.hitlist) # remove the agent from the memory
                    if neighbor.uid ∉ agent.goodlist
                        if length(agent.goodlist) < 150 # can be increased
                            push!(agent.goodlist, neighbor.uid) # add an entry at the end
                        else
                            deleteat!(agent.goodlist, 1) # remove first entry
                            push!(agent.goodlist, neighbor.uid) # add an entry at the end
                        end
                    end
                end
            elseif neighbor.choice == 1
                    if agent.choice == 1
                        filter!(x -> !(x == neighbor.uid), agent.hitlist) # remove the agent from the memory
                        if neighbor.uid ∉ agent.goodlist
                            if length(agent.goodlist) < 150 # can be increased
                                push!(agent.goodlist, neighbor.uid) # add an entry at the end
                            else
                                deleteat!(agent.goodlist, 1) # remove first entry
                                push!(agent.goodlist, neighbor.uid) # add an entry at the end
                            end
                        end
                    elseif agent.choice == 0
                        filter!(x -> !(x == neighbor.uid), agent.goodlist) # remove the agent from the memory
                        if neighbor.uid ∉ agent.hitlist
                            if length(agent.hitlist) < 150 # can be increased
                                push!(agent.hitlist, neighbor.uid) # add an entry at the end
                            else
                                deleteat!(agent.hitlist, 1) # remove first entry
                                push!(agent.hitlist, neighbor.uid) # add an entry at the end
                            end
                        end
                    end
            end
    end
    return
end

#### 3. RUNNING THE ACTUAL MODEL ####
## 3.1 START THE MODEL

# you can customize the model starting parameters here. E.g.: model = initialize(; coop_multiplier = 1.5,)
model = initialize(; coop_multiplier = 1.5,);


## 3.2 SETUP OUTPUT

# define a color dictionary for color marker. Each strategy has a different color
color_dict = Dict("coop" => "#00AAFF",
"defect" => "#FF88AA",
"random" => "#FFCC33",
"tft" => "#44FF88",
"pavlov" => "#DDBBFF",
"cd" => "#660099",
"cr" => "#006699",
"rd" => "#990000",
"" => "#FFFFFF", # we use white for cells with no strategy. Used only during setup
)
# set marker color based on the color dictionary
groupcolor(a) = color_dict[a.strategy]
# define marker shape - in this case, a filled square
groupmarker(a) = :rect


## 3.3 OUTPUT VIDEO

#=
# uncomment this block when outputting a video
CairoMakie.activate!() # need to activate this to output video
abm_video(
    "GroupAdvanced.mp4",
    model,
    agent_step!;
    ac = groupcolor,
    am = groupmarker,
    as = 10,
    spf = 1,
    framerate = 4,
    frames = 100,
    #    xticksvisible = false,
    title = "Evolutionary PD model",
)
=#

## 3.4 OUTPUT AN INTERACTIVE MODEL

## 3.4.1 SETUP THE INTERACTIVE MODEL
# this dictionary contains the sliders that will be shown on the interactive model
# we use the OrderedDict because normal Dict will randomly shuffly the sliders on display
#multipliers = OrderedDict(
multipliers = Dict(
:coop_strategy => 0:1:1,    # strategy sliders "switch" from 0 (off) to 1 (on)
:defect_strategy => 0:1:1,
:random_strategy => 0:1:1,
:tft_strategy => 0:1:1,
:pavlov_strategy => 0:1:1,
:cd_strategy => 0:1:1,
:cr_strategy => 0:1:1,
:rd_strategy => 0:1:1,
:coop_multiplier => -5:0.1:5,
:defect_multiplier => -5:0.1:5,
:sucker_multiplier => -5:0.1:5,
:punishment_multiplier => -5:0.1:5,
:threshold => 0:0.5:10,
)

# uncomment this block when running an interactive simulation
GLMakie.activate!()     # turn this on when using the interactive tool
# run the data simulation and pass in the necessary parameters
figure, p = abmexploration(
#figure = abmexploration(
    model;                      # our model
    agent_step!,                # agent interaction function
    model_step!,                # parsing through each step of the model
    params = multipliers,                # passing in the sliders
    ac = groupcolor,            # marker color
    am = groupmarker,           # marker shape
    as = 12,                    # marker size
    scheduler = Schedulers.randomly,    # agents will be called in random order
    figure = (; resolution = (1600,1200))
)

## 3.4.2 CREATE THE LEGEND
    # for each strategy, create a square filled with the corresponding color
    elem_1 = [PolyElement(color = "#00AAFF", strokecolor = :black, strokewidth = 1)]
    elem_2 = [PolyElement(color = "#FF88AA", strokecolor = :black, strokewidth = 1)]
    elem_3 = [PolyElement(color = "#FFCC33", strokecolor = :black, strokewidth = 1)]
    elem_4 = [PolyElement(color = "#44FF88", strokecolor = :black, strokewidth = 1)]
    elem_5 = [PolyElement(color = "#DDBBFF", strokecolor = :black, strokewidth = 1)]
    elem_6 = [PolyElement(color = "#660099", strokecolor = :black, strokewidth = 1)]
    elem_7 = [PolyElement(color = "#006699", strokecolor = :black, strokewidth = 1)]
    elem_8 = [PolyElement(color = "#990000", strokecolor = :black, strokewidth = 1)]

    # add the legend to the interactive model as another column

    leg = Legend(figure,
        [elem_1, elem_2, elem_3, elem_4, elem_5, elem_6, elem_7, elem_8],
        ["Cooperate", "Defect", "Random", "Tit For Tat", "Pavlov", "In-Coop-Out-Defect", "In-Coop-Out-Rand", "In-Random-Out-Defect"],
        halign = :center,
        valign = :center,
        patchsize = (25, 25),
        rowgap = 10,
        nbanks = 1)
    figure[2,2] = leg




##DEBUG
#=
for i in (1:5)
    for agent in allagents(model)
        agent_step!(agent, model)
    end
end
for neighbor in nearby_agents(random_agent(model), model)
    println(neighbor)
end

=#
