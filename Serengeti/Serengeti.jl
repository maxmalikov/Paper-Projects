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
using CSV                   # for data export
using DataFrames            # for dataframe manipulation

## 1.2 DEFINING AGENTS

mutable struct GroupAgent <: AbstractAgent
    id::Int                     # The internal model identifier number of the agent
    pos::NTuple{2,Int}          # The x, y location of the agent on a 2D grid
    uid::Int                    # the unique ID used for every new born agent
    strategy::String            # strategy used by the agent
    score::Float32              # used to keep score during interactions between agents
    choice::Int                 # 0 is defect, 1 is cooperate
    parents::Vector{Int}        # Parents' UID
    age::Int                    # Agent's age
    a_chromosome::Vector{Int}   # A chromosome
    b_chromosome::Vector{Int}   # B chromosome
    fitness::Float32            # Potential fitness based on the chromosomes
end

## 1.3 PARAMETERS

# You can use the following values for parameters to simulate stage games:

# Hawk-Dove
#=
defect_multiplier = 1.8
coop_multiplier = 0.9
sucker_multiplier = 0
punishment_multiplier = -0.1
=#

# Stag Hunt
#=
defect_multiplier = 1.0
coop_multiplier = 2.0
sucker_multiplier = 0.0
punishment_multiplier = 0.9
=#

#Prisoner's Dilemma
#=
defect_multiplier = 1.5
coop_multiplier = 1
sucker_multiplier = 0
punishment_multiplier = 0.1
=#

## 1.4 INITIALIZING GRIDSPACE

# This function creates the ABM, populates starting paremeters and sets up agents
function initialize(; numagents = 2500,
    griddims = (50, 50),
    agent_id = 0,
    step = 0,
    threshold = 6.0,
    # This is where we can adjust the payoff matrix for data processing!!!!!!
    # we need to pass the default payoff matrix values to the function
    defect_multiplier = 1.8,
    coop_multiplier = 0.9,
    sucker_multiplier = 0.0,
    punishment_multiplier = -0.1,
    # we also need to pass the strategies that will be used in the simulation
    coop_strategy = 1,      # 0 means not selected, 1 is selected
    defect_strategy = 1,
    gene_strategy = 1,
    density = 1.0,  # choose how densely populated the agents will be, from 0 to 1
    strangers = 2, # number of strangers to interact with
    agent_list = Vector{GroupAgent}(), # list of actual agents
    avg_fitness = 0.0,
    avg_score = 0.0,
    chromosome_size = 100,
    gene_pool = 0,
    coop_count = 0,
    defect_count = 0,
    gene_count = 0,
    death_log = [0 for i=1:25],
    life_expectancy = 0.0,
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
    :gene_strategy => gene_strategy,
    :density => density,
    :strangers => strangers,
    :agent_list => agent_list,
    :avg_fitness => avg_fitness,
    :avg_score => avg_score,
    :chromosome_size => chromosome_size,
    :gene_pool => gene_pool,
    :coop_count => coop_count,
    :defect_count => defect_count,
    :gene_count => gene_count,
    :death_log => death_log,
    :life_expectancy => life_expectancy,
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
        # setup blank agents. Set parent ID to self on initialization
        agent = GroupAgent(n, (1, 1), model.agent_id, "grass", 0.0, 0, [], rand(0:19), [], [], 0.0)
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

    # announce the model step - used during data export!
    if model.step % 100 == 0
        println(model.step)
    end
#=
    # alternate between Stag Hunt and Hawk-Dove
    if model.step % 2 == 0
        model.defect_multiplier = 1.8
        model.coop_multiplier = 0.9
        model.sucker_multiplier = 0.0
        model.punishment_multiplier = 0.0
    elseif model.step % 2 == 1
        model.defect_multiplier = 1.0
        model.coop_multiplier = 2.0
        model.sucker_multiplier = 0.0
        model.punishment_multiplier = 0.9
    end
=#
    # FIRST STEP
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
        if model.gene_strategy == 1
            push!(select_strategy, "gene")
        end
        # for each agent, set their strategy and reset values
        int_numagents = floor(Int, model.numagents*model.density)
        for n = 1:int_numagents
            # randomly select strategy from the strategy values vector
            model[n].strategy = select_strategy[rand(1:length(select_strategy))]
            # reset the score for the agents. Choice does not need to be reset
            model[n].score = 0.0
            # setup DNA
            # for the setup, populate DNA with 100 genes with 1 out of 3 alleles
            model[n].a_chromosome = [rand(0:2) for i=1:model.chromosome_size]
            model[n].b_chromosome = [rand(0:2) for i=1:model.chromosome_size]
            # calculate fitness - first get the dominant (here - maximum) expression of the genes
            max_chromosome = [max(model[n].a_chromosome[i], model[n].b_chromosome[i]) for i=1:model.chromosome_size]
            # then find total fitness - current fitness divided by average fitness of 1 chromosome (100)
            model[n].fitness = sum(max_chromosome) / model.chromosome_size
            # update the list of real agents
            push!(model.agent_list, model[n])
            # recalculate each agent's score based on their new strategy
            # interact!(model[n], model)

        end
        # for testing
        # model[rand(1:int_numagents)].strategy = "defect"
    # if this is not the first step, run agent_step! for each agent
    # no longer necessary
    #=
    else
        for agent in allagents(model)
            agent_step!(agent, model)
        end
    =#
    end

    # REPORTERS
    # setup blank placeholders
    total_fitness = 0.0
    total_score = 0.0
    total_gene_pool = 0
    gene_pool_list = [[0, 0, 0] for i=1:model.chromosome_size]
    total_coop = 0
    total_defect = 0
    total_gene = 0
    total_age = 0.0

    # calculate life expectancy based on the log of deaths
    for i in 1:length(model.death_log)
        total_age = total_age + (model.death_log[i]*(i-1))
    end

    # look through the list of active agents and calculate totals
    for agent in model.agent_list
        if agent.strategy == "coop"
            total_coop += 1
        elseif agent.strategy == "defect"
            total_defect += 1
        elseif agent.strategy == "gene"
            total_gene += 1
        end
        total_fitness = total_fitness + agent.fitness
        total_score = total_score + agent.score
        for gene in 1:length(agent.a_chromosome)
            if agent.a_chromosome[gene] == 0
                gene_pool_list[gene][1] += 1
            elseif agent.a_chromosome[gene] == 1
                gene_pool_list[gene][2] += 1
            elseif agent.a_chromosome[gene] == 2
                gene_pool_list[gene][3] += 1
            end
        end
        for gene in 1:length(agent.b_chromosome)
            if agent.a_chromosome[gene] == 0
                gene_pool_list[gene][1] += 1
            elseif agent.a_chromosome[gene] == 1
                gene_pool_list[gene][2] += 1
            elseif agent.a_chromosome[gene] == 2
                gene_pool_list[gene][3] += 1
            end
        end
    end
    # use the totals to calculate averages and store them in model reporters
    if sum(model.death_log) > 0
        model.life_expectancy = total_age / (sum(model.death_log))
    else
        model.life_expectancy = 0
    end
    # calculate other reporters
    model.coop_count = total_coop
    model.defect_count = total_defect
    model.gene_count = total_gene
    if length(model.agent_list) > 0
        for i in 1:length(gene_pool_list)
            total_gene_pool = total_gene_pool + count(x->(x>=1), gene_pool_list[i])
        end
        model.avg_fitness = total_fitness / length(model.agent_list)
        model.avg_score = total_score / length(model.agent_list)
        model.gene_pool = total_gene_pool
    else
        model.avg_score = 0.0
        model.avg_fitness = 0.0
        model.gene_pool = 0
    end
    # increment step counter to keep track of how many steps took place.
    # model.step will get reset to 0 when we click reset in the interactive tool.
    model.step += 1
end

## 2.1.2 STEP PERFORMED FOR EACH AGENT DURING EACH MODEL STEP
function agent_step!(agent, model)

    # After the first setup step, do the following
    if model.step != 0

        # INTERACT
        # interact with other agents to determine my score, unless no agent is present
        if agent.strategy != "grass"
            interact!(agent, model)
        end

        # AGE AND DEATH
        # update age
        agent.age += 1
        # modify score for elderly agents. If an agent is older than 10 years on average...
        if agent.age > 10
            # then slowly reduce their ability to obtain resources
            agent.score = (2 - (agent.age / 10)) * agent.score
        end
        # if not enough sustenance has been obtained, perish
        if agent.score < model.threshold && agent.strategy != "grass"
            agent.strategy = "grass"
            model.death_log[agent.age+1] += 1
            agent.age = 0
            agent.score = 0
            agent.fitness = 0
            agent.a_chromosome = []
            agent.b_chromosome = []
            agent.parents = []
            # remove our agent from the list of active agents
            deleteat!(model.agent_list, findfirst(x -> x.uid==agent.uid, model.agent_list))
        # REPRODUCTION
        # only can be done if there is space
        elseif agent.strategy == "grass"
            # first, find the nearby agents whose score is high enough to reproduce
            all_neighbors = collect(nearby_agents(agent, model))
            fit_neighbors = Vector{GroupAgent}()
            # make sure to only pick a parent that is old enough and can feed not only itself,
            # but also its child (that is, their score is at least 1.5 the threshold per parent)
            if length(all_neighbors) > 0
                for i in 1:length(all_neighbors)
                    if all_neighbors[i].score > model.threshold * 1.5 && all_neighbors[i].age >= 3
                        push!(fit_neighbors, all_neighbors[i])
                    end
                end
            end
            # pick a random qualified neighbor. If none, don't reproduce
            if length(fit_neighbors) > 0
                parent_1 = fit_neighbors[rand(1:length(fit_neighbors))]
                # pick another agent to reproduce with
                stranger_list = shuffle(model.agent_list)
                parent_2_id = 0
                for i in 1:length(stranger_list)
                    if stranger_list[i].score > model.threshold * 1.5 && stranger_list[i].age >= 3 && !check_relation(parent_1, stranger_list[i])
                        parent_2_id = i
                        break
                    end
                end
                # check if we found a parent 2
                if parent_2_id != 0
                    # if parent 2 exists, assign it to parent_2
                    parent_2 = stranger_list[parent_2_id]
                    # reset the agent, give it a new ID and increment the ID counter
                    agent.age = 0
                    agent.strategy = rand((parent_1.strategy, parent_2.strategy))
                    push!(agent.parents, parent_1.uid)
                    push!(agent.parents, parent_2.uid)
                    agent.uid = model.agent_id
                    # add our agent to the list of active agents
                    push!(model.agent_list, agent)
                    model.agent_id += 1
                    # MEIOSIS
                    # PARENT 1
                    # generate an average of 1.5 breakpoints
                    break_one_1 = rand(1:(model.chromosome_size - 1))
                    break_two_1_temp = rand(1:(model.chromosome_size - 1))
                    break_two_1 = 0
                    # verify that the second breakpoint is within the chromosome
                    if break_two_1_temp + break_one_1 < model.chromosome_size
                        break_two_1 = break_two_1_temp + break_one_1
                    end
                    # pick one of the chromosomes as the start
                    daughter_1 = rand(("a","b"))
                    # depending on which chromosome we start with and how many breaks, mix the chromosomes
                    if daughter_1 == "a" && break_two_1 == 0
                        agent.a_chromosome = [parent_1.a_chromosome[1:break_one_1]; parent_1.b_chromosome[break_one_1+1:end]]
                    elseif daughter_1 == "a" && break_two_1 != 0
                        agent.a_chromosome = [parent_1.a_chromosome[1:break_one_1]; parent_1.b_chromosome[break_one_1+1:break_two_1]; parent_1.a_chromosome[break_two_1+1:end]]
                    elseif daughter_1 == "b" && break_two_1 == 0
                        agent.a_chromosome = [parent_1.b_chromosome[1:break_one_1]; parent_1.a_chromosome[break_one_1+1:end]]
                    elseif daughter_1 == "b" && break_two_1 != 0
                        agent.a_chromosome = [parent_1.b_chromosome[1:break_one_1]; parent_1.a_chromosome[break_one_1+1:break_two_1]; parent_1.b_chromosome[break_two_1+1:end]]
                    end
                    # PARENT 2
                    # generate an average of 1.5 breakpoints
                    break_one_2 = rand(1:(model.chromosome_size - 1))
                    break_two_2_temp = rand(1:(model.chromosome_size - 1))
                    break_two_2 = 0
                    # verify that the second breakpoint is within the chromosome
                    if break_two_2_temp + break_one_2 < model.chromosome_size
                        break_two_2 = break_two_2_temp + break_one_2
                    end
                    # pick one of the chromosomes as the start
                    daughter_2 = rand(("a","b"))
                    # depending on which chromosome we start with and how many breaks, mix the chromosomes
                    if daughter_2 == "a" && break_two_2 == 0
                        agent.b_chromosome = [parent_2.a_chromosome[1:break_one_2]; parent_2.b_chromosome[break_one_2+1:end]]
                    elseif daughter_2 == "a" && break_two_2 != 0
                        agent.b_chromosome = [parent_2.a_chromosome[1:break_one_2]; parent_2.b_chromosome[break_one_2+1:break_two_2]; parent_2.a_chromosome[break_two_2+1:end]]
                    elseif daughter_2 == "b" && break_two_2 == 0
                        agent.b_chromosome = [parent_2.b_chromosome[1:break_one_2]; parent_2.a_chromosome[break_one_2+1:end]]
                    elseif daughter_2 == "b" && break_two_2 != 0
                        agent.b_chromosome = [parent_2.b_chromosome[1:break_one_2]; parent_2.a_chromosome[break_one_2+1:break_two_2]; parent_2.b_chromosome[break_two_2+1:end]]
                    end
                    # MUTATION
                    # go through every gene
                    for i in 1:length(agent.a_chromosome)
                        # if the gene happens to be 1 in 3366, mutate it
                        # see below why we use 2244 instead
                        if rand(1:2244) == 1
                            # pick a random value between 0 and 2. This may return the same value as before, thus
                            # this will effectively keep the rate of mutation at 1 in 3366 instead of 2244
                            agent.a_chromosome[i] = rand(0:2)
                        end
                    end
                    for i in 1:length(agent.b_chromosome)
                        # if the gene happens to be 1 in 3366, mutate it
                        # see below why we use 2244 instead
                        if rand(1:2244) == 1
                            # pick a random value between 0 and 2. This may return the same value as before
                            # this will effectively keep the rate of mutation at 1 in 3366 instead of 2244
                            agent.b_chromosome[i] = rand(0:2)
                        end
                    end
                    # OPTIONAL - MUTATE STRATEGY
                    # if the gene happens to be 1 in 3366, mutate it
                    # see below why we use 2244 instead

                    if rand(1:2244) == 1
                        # pick a random value between 0 and 2. This may return the same value as before
                        # this will effectively keep the rate of mutation at 1 in 3366 instead of 2244
                        agent.strategy = rand(["coop", "defect", "gene"])
                    end

                    # CALCULATE FITNESS
                    # calculate fitness - first get the dominant (here - maximum) expression of the genes
                    max_new_chromosome = [max(agent.a_chromosome[i], agent.b_chromosome[i]) for i=1:model.chromosome_size]
                    # then find total fitness - current fitness divided by average fitness of 1 chromosome (100)
                    agent.fitness = sum(max_new_chromosome) / model.chromosome_size

                    # let the parent give their child enough resources to survive
                    # this way, a very successful agent can have multiple offspring
                    agent.score = model.threshold
                    parent_1.score = parent_1.score - (model.threshold * 0.5)
                    parent_2.score = parent_2.score - (model.threshold * 0.5)
                end
            end
        end
    end
    return
end

## 2.2 DEFINING INTERACTION BETWEEN AGENT
function interact!(agent, model)
    agent.score = 1 # start at 1 to simulate successful hunting in your own domain
    # get a list of everyone we need to work with
    interaction_list = Vector{GroupAgent}()
# GET STRANGERS
    # find random strangers from the active agent list
    if model.strangers > 0 && length(model.agent_list) > 0
        for s in 1:model.strangers
            push!(interaction_list, model.agent_list[rand(1:length(model.agent_list))])
        end
    end

# GET NEIGHBORS
    neighbors_list = collect(nearby_agents(agent, model))
    interaction_list = [interaction_list; neighbors_list]
# INTERACT
    for neighbor in interaction_list
        # if no neighbor is present, simply hunt
        if neighbor.strategy == "grass"
            # increment the score by 1 due to a successful hunt of a small prey
            agent.score = agent.score + 1
        else
            # add some randomness to the payoff values - setup variable multiplier values
            cm = model.coop_multiplier * (0.9 + rand()*0.2)
            dm = model.defect_multiplier * (0.9 + rand()*0.2)
            sm = model.sucker_multiplier * (0.9 + rand()*0.2)
            pm = model.punishment_multiplier * (0.9 + rand()*0.2)
            # pick the choice for both the agent and the neighbor/stranger
            if neighbor.uid != agent.uid # only run for agents other than myself
                select_choice!(neighbor, agent, model, neighbors_list, cm, dm, sm, pm) # define the choice of my neighbor
                select_choice!(agent, neighbor, model, neighbors_list, cm, dm, sm, pm) # define my choice
                # increment my score based on our choices. Choice 1 is cooperate, 0 is defect
                if neighbor.choice == 1
                    if agent.choice == 1
                        # the multipliers are part of the model, thus are called as model property
                        agent.score = agent.score + cm
                    elseif agent.choice == 0
                        agent.score = agent.score + dm
                    end
                elseif neighbor.choice == 0
                    if agent.choice == 1
                        agent.score = agent.score + sm
                    elseif agent.choice == 0
                        agent.score = agent.score + pm
                    end
                end
            end
        end
    end
    # update the score based on the fitness
    agent.score = agent.score * agent.fitness
    return
end

## 2.3 CHECK RELATION

function check_relation(agent, neighbor)
    if neighbor.uid in agent.parents
        return true
    # if the neighbor is an offspring, set the shared gene value to 0.5
    elseif agent.uid in neighbor.parents
        return true
    # make sure there are 2 parents in the array to reference
    elseif length(neighbor.parents) > 1
        # check if the agents are siblings
        if neighbor.parents[1] in agent.parents || neighbor.parents[2] in agent.parents
            return true
        end
    end
    return false
end

## 2.4 SELECTING A CHOICE

function select_choice!(agent, neighbor, model, neighbors_list, cm, dm, sm, pm)
    # for each type of strategy, generate an appropriate choice
    # 1 is cooperate, 0 is defect
    if agent.strategy == "coop"
        agent.choice = 1
    elseif agent.strategy == "defect"
        agent.choice = 0
    elseif agent.strategy == "gene"
        # set relative multiplier to a small, but not negligible multiplier
        rm = 0.05
        # if the neighbor is related, set shared gene value to 0.5
        if check_relation(agent, neighbor)
            rm = 0.5
        elseif neighbor in neighbors_list
            rm = 0.2
        end
        # now, determine whether cooperation or defection is better
        sum_coop = cm + cm * rm + sm + dm * rm
        sum_defect = dm + sm * rm + pm + pm * rm
        # compare the values
        if sum_coop >= sum_defect
            agent.choice = 1
        else
            agent.choice = 0
        end
    end
    return
end

#### 3. RUNNING THE ACTUAL MODEL ####
## 3.1 START THE MODEL

# you can customize the model starting parameters here. E.g.: model = initialize(; coop_multiplier = 1.5,)
model = initialize();

## 3.1.1 Export data

#=

mdata = [:avg_fitness, :avg_score, :gene_pool, :life_expectancy, :coop_count, :defect_count, :gene_count]
# data_m is the model dataframe
data_a, data_m = run!(model, agent_step!, model_step!, 10002; mdata)

# strip 99 out 100 rows
outframe = subset(data_m, :step => a -> mod.(a, 100) .== 2)

# open a CSV file and write the results
touch("serengeti_gene_hd4.csv")
efg = open("serengeti_gene_hd4.csv")
CSV.write("serengeti_gene_hd4.csv", outframe)
close(efg)

=#

## 3.2 SETUP OUTPUT

# define a color dictionary for color marker. Each strategy has a different color
color_dict = Dict("coop" => "#FFEAAA",
"defect" => "#954F00",
"gene" => "#E6A42B",
"grass" => "#9BD87F",
"" => "#9BD87F", # we use green for cells with no strategy. Used only during setup
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
    "Serengeti.mp4",
    model,
    agent_step!;
    ac = groupcolor,
    am = groupmarker,
    as = 12,
    spf = 1,
    framerate = 4,
    frames = 100,
    #    xticksvisible = false,
    title = "Serengeti",
)
=#

## 3.4 OUTPUT AN INTERACTIVE MODEL

## 3.4.1 SETUP THE INTERACTIVE MODEL
# this dictionary contains the sliders that will be shown on the interactive model
# we use the OrderedDict because normal Dict will randomly shuffly the sliders on display

# uncomment to use interactive tool



multipliers = OrderedDict(
#multipliers = Dict(
:coop_strategy => 0:1:1,    # strategy sliders "switch" from 0 (off) to 1 (on)
:defect_strategy => 0:1:1,
:gene_strategy => 0:1:1,
:coop_multiplier => -5:0.1:5,
:defect_multiplier => -5:0.1:5,
:sucker_multiplier => -5:0.1:5,
:punishment_multiplier => -5:0.1:5,
:threshold => 0:0.5:10,
:strangers => 0:1:10,
)

# uncomment this block when running an interactive simulation
GLMakie.activate!()     # turn this on when using the interactive tool
# Data collection
mdata = [:avg_fitness, :avg_score, :gene_pool, :life_expectancy, :coop_count, :defect_count, :gene_count]

# run the data simulation and pass in the necessary parameters
figure, p = abmexploration(
    model;                      # our model
    agent_step!,                # agent interaction function
    model_step!,                # parsing through each step of the model
    params = multipliers,       # passing in the sliders
    ac = groupcolor,            # marker color
    am = groupmarker,           # marker shape
    as = 12,                    # marker size
    scheduler = Schedulers.randomly,            # agents will be called in random order
    figure = (; resolution = (1800,1200),),     # specify resolution
    axis = (; backgroundcolor = "#9BD87F",),    # pain background green
    mdata, mlabels = ["Average Fitness", "Average Score", "Gene Pool", "Life Expectancy", "Cooperators", "Defectors", "Gene-Centric"], # output graphs
)

## 3.4.2 CREATE THE LEGEND
    # for each strategy, create a square filled with the corresponding color
    elem_1 = [PolyElement(color = "#FFEAAA", strokecolor = :black, strokewidth = 1)]
    elem_2 = [PolyElement(color = "#E6A42B", strokecolor = :black, strokewidth = 1)]
    elem_3 = [PolyElement(color = "#954F00", strokecolor = :black, strokewidth = 1)]
    elem_4 = [PolyElement(color = "#9BD87F", strokecolor = :black, strokewidth = 1)]

    # add the legend to the interactive model as another column

    leg = Legend(figure,
        [elem_1, elem_2, elem_3, elem_4],
        ["Cooperate", "Gene-Centered", "Defect", "Grass"],
        halign = :center,
        valign = :center,
        patchsize = (25, 25),
        rowgap = 10,
        nbanks = 1)
    figure[1,3] = leg
