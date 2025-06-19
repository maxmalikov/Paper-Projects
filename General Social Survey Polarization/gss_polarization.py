# -*- coding: utf-8 -*-
"""
CSS 692 Social Network analysis
Spring 2022
Final Project
Max Malikov

"""

############################### 1. GETTING DATA ###############################################

## IMPORT NECESSARY LIBRARIES ----------------------------------------------------------------

import networkx as nx # Import networkx
from networkx.algorithms import community # to support community detection
import matplotlib.pyplot as plt # Import plotting library
import random # Import random number generator library
import numpy as np # for processing data
import math # For combination calculation
import copy # for deep copy
from matplotlib.axes._axes import _log as matplotlib_axes_logger # to suppress warnings

## IMPORT DATA ----------------------------------------------------------------

# This function loads a network file and creates a NetworkX object based on it
def createNetworkFromFile(inFile):

     # Read in the file specified in the input
     inputStream = open(inFile, 'r')
     # Create placeholders for our data
     lines = []
     dataset = []
     outGraph = nx.Graph()
     

     # create a list containing every line in the file
     for line in inputStream:
         lines.append(line.strip())
          
     # Stop reading the file
     inputStream.close()
     
     for singleLine in lines[1:]:
         dataset.append(singleLine.split(","))
     
     # process the list of values into a network
     for lineIterator1 in range(len(dataset)):
         # we need to add every node, even if it will not be connected
         outGraph.add_node(lineIterator1)
         for lineIterator2 in range(lineIterator1+1,len(dataset)):
             # reset the count of matching answers
             matches = 0
             # loop through the answers to find matches
             for answersIterator in range(len(dataset[lineIterator1])):
                 if (dataset[lineIterator1][answersIterator] == dataset[lineIterator2][answersIterator]):
                     # increment match counter
                     matches = matches + 1
             # if the number of matches is greather than threshold, create an edge
             # The threshold is calculated based on a normal distribution approximation,
             # where the mean is calculated as n*p,
             # and the standard deviation is calculated as sqrt(n*p*(1-p)), where
             # n = the number of answers and p = average probability of an answer in a question.
             # For 1978, 1988, 1998 and 2018, change the number below to 11
             # For 2008, change the number to 10
             if matches > 11:
                 outGraph.add_edge(lineIterator1, lineIterator2)
         
     # return the final completed network
     return outGraph
 
    
####################################### 2. PROCESSING DATA ###################################### 
    
## UTILITY FUNCTIONS FOR CALCULATIONS -----------------------------------------------------------

# This function calculates the number of V shapes for a given node
def getVShapeCount(graph, node1):
    
    # since the number of v-shapes is equal to node degree chooses 2,
    # we can simply calculate the result using built-in math function
    return int(math.comb(graph.degree(node1), 2))


# This function calculates the number of triangles for a given node
def getTriangleCount(graph, node1):

    # setup a counter for triangles
    triangleCount = 0
    # get the list of neighboring nodes
    neighborNodes = list(graph.neighbors(node1))
    numberOfNeighbors = len(neighborNodes)
    nodeIterator = 0
    while nodeIterator < numberOfNeighbors: 
        firstNode = neighborNodes[nodeIterator]
        del neighborNodes[nodeIterator]
        numberOfNeighbors = numberOfNeighbors - 1

        # iterate through the list again, and check for a connection between the two nodes 
        for secondNode in neighborNodes:
            # check for the connection
            if graph.has_edge(firstNode, secondNode):
                # if there is a connection, increment the counter
                triangleCount = triangleCount + 1
                        
    return triangleCount

# This function calculates the Global Clustering of a network
def getGlobalClustering(graph):
        
    # v-shape counter:
    vShapeCount = 0
    # triangle counter:
    triangleCount = 0
    
    # iterate over all nodes
    for tempNode in list(graph.nodes()):
        # increment the v-shapre tracker by the number of v-shapes found
        vShapeCount = vShapeCount + getVShapeCount(graph, tempNode)
        # increment the triangle tracker by the number of triangles found
        triangleCount = triangleCount + getTriangleCount(graph, tempNode)
        
    # return the result of calculation as the global clustering value    
    return triangleCount / vShapeCount

# This function calculates the Local Clustering of a node
def getLocalClustering(graph, node1):
        
    # get V Shape count
    vCount = getVShapeCount(graph, node1)
    # get Triangle count
    tCount = getTriangleCount(graph, node1)
    
    # check if the V Shape count is greater than 0 to avoid division by 0
    if vCount > 0:
        return tCount / vCount
    else:
        return 0

## UTILITY FUNCTIONS FOR GETTING NODE LISTS -----------------------------------------------------

# This function generates a list of clustering counts
# Provided through class
def clistWS(graph):
    # create a list of nodes
    allNodes = list(nx.nodes(graph))
    # create a placeholder to hold the list of local cluster counts
    cList = []
    # iterate over the list of nodes and populate our list with the local cluster counts
    for node in allNodes:
        cList.append(getLocalClustering(graph, node))
                
    # return the list
    return cList

# This is a histogram function for handling a list with fractional values
# Provided through class
def histogram(InList, Nbin):
    xmin = min(InList)  # Find the minimum value of InList
    xmax = max(InList)  # Find the maximum value of InList
    dx = float(xmax - xmin) / Nbin  # Find bin widths
    H = {}  # Define the histogram
    for x in InList:  # Loop over data
        if x == xmax:  # If x== xmax , store in last bin
            q = Nbin
        else:  # Else , find bin
            q = int((x - xmin) / dx) + 1
        H[q] = H . get(q, 0) + 1  # Populate histogram
    xcoord = {}  # Create horizontal coord dictionary
    for q in H . keys():
        xcoord[q] = xmin + (q - 1) * dx  # Using left end of bin .
        # xcoord [q]= xmin +(q -0.5) *dx # This would be mid -bin .
        
    return (xcoord, H)


## UTILITY FUNCTIONS FOR PLOTTING ------------------------------------------------------------

# This function plots the histogram of a list with fractional values
def plotFloatHist(Graph, Nbin):
    # get the clustering list for our Graph
    cList = clistWS(Graph)
    # retrieve the dictionaries containing x coordinates and the values
    xcoord, H = histogram(cList, Nbin)
    # plot the values
    plt.plot(list(xcoord.values()), list(H.values()), 'o', markersize = 10)
    plt.title("Histogram of Local Clustering counts")
    plt.xlabel("Local Clustering Value")
    plt.ylabel("Occurances")
    plt.show()

# This function plots log scale version of the histogram function  
def plotFloatHistLog(Graph, Nbin):
    # get the clustering list for our Graph
    cList = clistWS(Graph)
    # retrieve the dictionaries containing x coordinates and the values
    xcoord, H = histogram(cList, Nbin)
    # plot the values
    plt.plot(list(xcoord.values()), list(H.values()), 'o', markersize = 10)
    plt.title("Histogram of Local Clustering counts")
    plt.xlabel("Local Clustering Value")
    plt.ylabel("Occurances")
    plt.yscale('log')
    #plt.xscale('log')
    plt.show()  
    
################################ 3. GENERATING OUTPUT DATA ####################################

## SINGLE NETWORK INPUT ---------------------------------------------------------------------

# This function generates clustering data for a network
def generateClusteringData(Graph):
    
    # Generate some temporary variables to store our values and populate them
    # Network link density
    tempDensity = nx.density(Graph)
    # Network Global Clustering
    tempClustering = getGlobalClustering(Graph)
    # List of local clustering values for every node
    tempCList = clistWS(Graph)
    
    # Print out the results
    print("Link Density is %4f" % (tempDensity))
    print("Clustering is %4f" % (tempClustering))
    # Using numpy to generate standard deviation of our list of clustering values
    print("Standard Deviation is %4f" % (np.std(tempCList)))
    print("Plotting histogram...")
    # Plot the results on a log scale chart
    plotFloatHistLog(Graph, 40)
    
    
# This function is used to determine the number of communities in a network and plot them.
def getCommunities(Graph):
    
    # Create a temporary network, so that we do not change the original network.
    tempGraph = copy.deepcopy(Graph)
    # Remove disconnected nodes from the temporary network - since we are not interested in communities that
    # are thsoe that are larger than 1
    tempGraph.remove_nodes_from(list(nx.isolates(tempGraph)))
    # perform a Clauset-Newman-Moore communitiy detection
    communities = community.greedy_modularity_communities(tempGraph)
    print("Number of communities is %4d" % (len(communities)))
    # Now, let's calculate the Effective Number of Parties (ENP) calculation to get the weighted number of communities
    # The formula is 1 / SUM OF (EVERY COMMUNITY PROPORTION ) ^ 2
    # First, calculate the sum. Create a placeholder to store the sum value.
    communitySum = 0 
    # Calculate the square of each community proportion of the entire population and add it to the sum variable.
    for com in communities:
        communitySum = communitySum + (len(com)/Graph.number_of_nodes())**2
    # print out the resulting ENP
    print("The Effective Number of Parties (communities) is %4f" % (1/communitySum))
           
    # suppress matplotlib warnings about random colors
    matplotlib_axes_logger.setLevel('ERROR')
    
    # fix the position of the network plot
    pos = nx.spring_layout(tempGraph)
    
    # draw the network layout - we will color over it below
    nx.draw(tempGraph, pos, edge_color='k', node_size= 5, width= 0.2)
    # iterate over the node list of the communities
    for com in range(len(communities)):
        # for our reference - print out the community size
        print("Size of the community %4d is %4d" % (com, len(communities[com])))
        # Also, print out the average local clustering for the community
        print("Average Local Clustering of the community is %4f" % (nx.average_clustering(tempGraph, nodes=communities[com])))
        # since we don't know the number of communities, we can colorize them semi-randomly
        # to make sure that the communities have distinct colors, we limit the number of colors
        # that each subsequent community can pull from. Above 5 communities, we keep generating
        # different colors, although they now can be from the same color region as previous communities
        if com%5 == 0:
            # e.g. This will generate a color with low amount of red, low amount of green, and high amount of blue (RGB)
            tempColor = (random.random()/3, random.random()/3, (random.random()/2)+0.5)
        elif com%5 == 1:
            tempColor = ((random.random()/2)+0.5, random.random()/3, random.random()/3)
        elif com%5 == 2:
            tempColor = ((random.random()/2)+0.5, (random.random()/2)+0.5, random.random()/3)
        elif com%5 == 3:
            tempColor = (random.random()/3, (random.random()/2)+0.5, random.random()/3)
        elif com%5 == 4:
            tempColor = ((random.random()/2)+0.5, random.random()/3, (random.random()/2)+0.5)
        
        # add the nodes from this specific community to the plot
        nx.draw_networkx_nodes(tempGraph, pos, nodelist=communities[com], node_color=tempColor, node_size= 10)
        
    # display the plot
    plt.show()

## MULTI NETWORK INPUT ---------------------------------------------------------------------------

   
# plot a clustering histogram of several networks at once
def compareClustering(inList):

    for i in range(len(inList)):
        
        # We use modulo division to colorize input networks differently
        # Generate colors for each network. If more than 6 networks are passed in, the additional
        # networks will get different colors from the first 6. See above for details
        if i%6 == 0:
            # This will generate a strongly blue color, etc.
            tempColor = (random.random()/4, random.random()/4, (random.random()/4)+0.75)
        elif i%6 == 1:
            tempColor = ((random.random()/4)+0.75, random.random()/4, random.random()/4)
        elif i%6 == 2:
            tempColor = ((random.random()/4)+0.75, (random.random()/4)+0.75, random.random()/4)
        elif i%6 == 3:
            tempColor = (random.random()/4, (random.random()/4)+0.75, random.random()/4)
        elif i%6 == 4:
            tempColor = ((random.random()/4)+0.75, random.random()/4, (random.random()/4)+0.75)
        elif i%6 == 5:
            tempColor = (random.random()/4, random.random()/4, random.random()/4)
        
        
        # get the clustering list for our Graph
        cList = clistWS(inList[i])
        # retrieve the dictionaries containing x coordinates and the values fillstyle='none',
        xcoord, H = histogram(cList, 40)

        plt.plot(list(xcoord.values()), list(H.values()), 'o', markersize = 10,  color=tempColor)
    
    # now we can add some detailed information to the overall plot
    plt.title("Histogram of Local Clustering counts")
    plt.xlabel("Local Clustering Value")
    plt.ylabel("Occurences")
    # change the scale to Log on the Y axis due to the large number of nodes
    plt.yscale('log')
    plt.legend(["Random", "1978", "1988", "1998", "2008", "2018"], loc=0)
    # display the plot
    plt.show()
    

############################### 4. MAIN PROGRAM ##############################################

## GATHER DATA --------------------------------------------------------------------------------

n78 = createNetworkFromFile("GSS1978_reduced.csv")
n88 = createNetworkFromFile("GSS1988_reduced.csv")
n98 = createNetworkFromFile("GSS1998_reduced.csv")
n08 = createNetworkFromFile("GSS2008_reduced.csv")
n18 = createNetworkFromFile("GSS2018_reduced.csv")
r1 = createNetworkFromFile("sample_input.csv")
r2 = createNetworkFromFile("sample_input2.csv")
    
graphList1 = [r1, n78]
graphList2 = [r1, n78, n88, n98, n08, n18]

## PROCESS THE DATA -----------------------------------------------------------------------

# Uncomment to run it all
"""
generateClusteringData(n78)
generateClusteringData(n88)
generateClusteringData(n98)
generateClusteringData(n08)
generateClusteringData(n18)
generateClusteringData(r1)

getCommunities(n78)
getCommunities(n88)
getCommunities(n98)
getCommunities(n08)
getCommunities(n18)
getCommunities(r1)

compareClustering(graphList1)
compareClustering(graphList2)
"""

################################## 5. TESTING #########################################

# This function was used for testing - ignore    
def generateData(Graph):
    print("Link Density is %4f" % (nx.density(Graph)))
    print("Clustering is %4f" % (nx.average_clustering(Graph)))
    # draw the graph
    print("Generating graph plot...")
    nx.draw(Graph, node_size=10, width=0.5)
    plt.show()
    # generate the largest component
    print("Generating plot of the largest network component...")
    graphConstructor = sorted(nx.connected_components(Graph), key=len, reverse=True)
    subgraph1 = Graph.subgraph(graphConstructor[0])
    nx.draw(subgraph1, node_size=10, width=0.2)
    plt.show()
    #communities = algorithms.leiden(Graph)
    #print("Number of communities is %4d" % (len(communities)))
    communities = community.greedy_modularity_communities(Graph)
    print("Number of communities is %4d" % (len(communities)))
    subcommunities = community.greedy_modularity_communities(subgraph1)
    print("Number of communities is %4d" % (len(subcommunities)))
    
    pos = nx.spring_layout(subgraph1)
    nx.draw(subgraph1, pos, edge_color='k', node_size= 5, width= 0.2)
    for com in range(len(subcommunities)):
        nx.draw_networkx_nodes(subgraph1, pos, nodelist=subcommunities[com], node_color=(random.random(), random.random(), random.random()), node_size= 10)
    plt.show()

