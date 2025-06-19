# -*- coding: utf-8 -*-
"""
Created on Fri Nov 26 22:12:37 2021

@author: Max
"""

import numpy as np
import random
import copy
import pandas as pd

rewardPayoff = 5
temptationPayoff = 0
suckerPayoff = -5
punishmentPayoff = 0
IDSequence = 0

class agent():
    agentID = 0
    YChromosome = [0, 0, 0, 0]
    GChromosome = [0, 0, 0, 0]
    score = 0.0
    socksColor = ""
    choice = 0
    
    def __init__(self, agentID, YChromosome, GChromosome, score, socksColor, choice):
        self.agentID = agentID
        self.YChromosome = YChromosome
        self.GChromosome = GChromosome
        self.score = score
        self.socksColor = socksColor
        self.choice = choice
    
    def __str__(self):
        return "ID: {0}, Y: {1}, G: {2}, Score: {3}, Group: {4}, Choice: {5}".format(self.agentID,
            self.YChromosome, self.GChromosome, self.score, self.socksColor, self.choice)
        
    def reset(self):
        self.score = 0.0
        
    
def SetupAgents(yellowGroup, greenGroup):
    global IDSequence
    for i in range(50):
        tempYChromosome = []
        tempGChromosome = []
        for j in range(4):
            tempYChromosome.append(random.randint(0,1))
            tempGChromosome.append(random.randint(0,1))
        tempAgent = agent(IDSequence, tempYChromosome, tempGChromosome, 0.0, "yellow", random.randint(0, 1))
        yellowGroup.append(tempAgent)
        IDSequence += 1
    for i in range(50):
        tempYChromosome = []
        tempGChromosome = []
        for j in range(4):
            tempYChromosome.append(random.randint(0,1))
            tempGChromosome.append(random.randint(0,1))
        tempAgent = agent(IDSequence, tempYChromosome, tempGChromosome, 0.0, "green", random.randint(0, 1))
        greenGroup.append(tempAgent)
        IDSequence += 1
      
        
# Shuffle the group to avoid repeating sequences. Call each agent to perform their steps.
# Based on the scores, cull the worst performing agents and breed new ones to take their place 
def ModelStep(yellowGroup, greenGroup):
    np.random.shuffle(yellowGroup)
    np.random.shuffle(greenGroup)
    for agent in yellowGroup:
        AgentStep(agent, yellowGroup, greenGroup)
    for agent in greenGroup:
        AgentStep(agent, yellowGroup, greenGroup)
    # print("before: ", len(yellowGroup))
    CullAgents(yellowGroup)
    # print("culled: ", len(yellowGroup))
    CullAgents(greenGroup)
    BreedAgents(yellowGroup)
    # print("born: ", len(yellowGroup))
    BreedAgents(greenGroup)
    
# For each agent, interact with 25 other agents from each group        
def AgentStep(agent, yellowGroup, greenGroup):
    # First, create a temp group that does not contain our agent
    tempYellow = []
    tempGreen = []
    agent.score = 0
    for tempAgent in yellowGroup:
        if tempAgent.agentID != agent.agentID:
            tempYellow.append(tempAgent)
    for tempAgent in greenGroup:
        if tempAgent.agentID != agent.agentID:
            tempGreen.append(tempAgent)
    # Now, interact with 40 randomly sampled agents from each group
    if agent.socksColor == "yellow":          
        for opponent in random.sample(tempYellow, 20): # return 40 samples from our 50 agent set
            Interact(agent, opponent)
        for opponent in random.sample(tempGreen, 20): # return 40 samples from our 50 agent set
            Interact(agent, opponent)
    if agent.socksColor == "green":          
        for opponent in random.sample(tempYellow, 20): # return 40 samples from our 50 agent set
            Interact(agent, opponent)
        for opponent in random.sample(tempGreen, 20): # return 40 samples from our 50 agent set
            Interact(agent, opponent)
    
# Interact with another agent and increment score based on the interaction
def Interact(agent, opponent): 
    SelectChoice(agent, opponent)
    SelectChoice(opponent, agent)
    if opponent.choice == 1:
        if agent.choice == 1:
            agent.score = agent.score + rewardPayoff
        elif agent.choice == 0:
            agent.score = agent.score + temptationPayoff
    elif opponent.choice == 0:
        if agent.choice == 1:
            agent.score = agent.score + suckerPayoff
        elif agent.choice == 0:
            agent.score = agent.score + punishmentPayoff
        
# Return agent's choice weighted baed on their Chromosomes 
def SelectChoice(agent, opponent):
    if opponent.socksColor == "yellow":
        agent.choice = random.choices(agent.YChromosome, weights = [8, 4, 2, 1])[0]
    elif opponent.socksColor == "green":
        agent.choice = random.choices(agent.GChromosome, weights = [8, 4, 2, 1])[0]
 
# Sort agents in a group by score, and prune 20 lowest scores
def CullAgents(group):

    group.sort(key=lambda x: x.score)
#    print("BEFORE")
#    for x in group:
#        print(x)
    del group[:20]
#    print("AFTER")
#    for x in group:
#        print(x)
#    print("OK")
    
# Create 20 new agents for each group, mutate them and append to the original group
def BreedAgents(group):
    global IDSequence
    tempWeights = []
    # generate the weights based on agent's score
    for agent in group:
        tempWeights.append(agent.score)
    # create 20 new agent copies proportional to the "score" from the original group
    tempGroup = []


    for i in range(20):
        tempAgentList = copy.deepcopy(random.choices(group, weights = tempWeights, k=1)) 
        # Give the agent a new ID

        tempAgentList[0].agentID = IDSequence 
        IDSequence += 1
        Mutate(tempAgentList[0])
        tempGroup.extend(tempAgentList)

    group.extend(tempGroup)
    
# Flip the Chromosome bit with a probability of 0.1% each bit
# This means that there is a 99.2% chance that no bit will be mutated   
def Mutate(agent): 

    for index, value in enumerate(agent.YChromosome):
        if random.random() > 0.999:
            agent.YChromosome[index] = 1 - agent.YChromosome[index]
    for index, value in enumerate(agent.GChromosome):
        if random.random() > 0.999:
            agent.GChromosome[index] = 1 - agent.GChromosome[index]

            
# MAIN FUNCTION THAT CALLS OTHERS    
def MainSim():


    outputDF = pd.DataFrame({'yellows_yellow': [],
                           'yellows_green': [], 
                           'greens_yellow': [], 
                           'greens_green': []})
    for j in range (1):
        yellowGroup = []
        greenGroup = []
        SetupAgents(yellowGroup, greenGroup)
        for i in range (1000):
            ModelStep(yellowGroup, greenGroup)
            yellowsYellow = 0
            yellowsGreen = 0
            greensYellow = 0
            greensGreen = 0
            for x in yellowGroup:
                yellowsYellow = yellowsYellow + x.YChromosome[0]*8 + x.YChromosome[1]*4 +  + x.YChromosome[2]*2 +  + x.YChromosome[3]
                yellowsGreen = yellowsGreen + x.GChromosome[0]*8 + x.GChromosome[1]*4 +  + x.GChromosome[2]*2 +  + x.GChromosome[3]
            for x in greenGroup:
                greensYellow = greensYellow + x.YChromosome[0]*8 + x.YChromosome[1]*4 +  + x.YChromosome[2]*2 +  + x.YChromosome[3]
                greensGreen = greensGreen + x.GChromosome[0]*8 + x.GChromosome[1]*4 +  + x.GChromosome[2]*2 +  + x.GChromosome[3]
            outputDF.loc[len(outputDF.index)] = [yellowsYellow*100/(15*50), yellowsGreen*100/(15*50), greensYellow*100/(15*50), greensGreen*100/(15*50)]


        print(j)
    outputDF.to_csv("one_run.csv")
    print("done!")
    
MainSim()
