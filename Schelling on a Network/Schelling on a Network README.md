This model expands the classic Schelling's model of segregation to allow for use of any arbitrary network to be used as the environment in which the agents live. It is also possible to generate a network to be used as the environment using NetworkX module capabilities.

The visualization of the model has been removed in favor of allowing the model to run at very large sizes, as well as being able to repeat a designated number of runs. The output of this model has been changed to simply produce CSV files with the final result data.

**Software files:**
- app_headless.py - used to run multiple instances of the model and to load the network to be used for the environment
- model.py - the actual model file that coordinates agents and environment
- agents.py - this file dictates the actions of the agents every step of the model.

**Software versions:**
- Mesa 3.0
- NetworkX 3.6
- Python 3.10
