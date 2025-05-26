from mesa import Agent, Model
from mesa.time import RandomActivation
from mesa.datacollection import DataCollector
from mesa.space import MultiGrid

import random

# Define tasks
TASKS = ['Foraging', 'Nursing']

class BeeAgent(Agent):
    def __init__(self, unique_id, model):
        super().__init__(model)  # Properly initialize the Agent parent class
        # Random threshold for each task between 0 and 1
        self.thresholds = {task: random.uniform(0, 1) for task in TASKS}
        self.current_task = None
    
    def step(self):
        stimuli = self.model.task_stimuli
        # Decide task to perform based on threshold and stimulus
        # Probability to do task = stimulus / (stimulus + threshold)
        probabilities = {}
        for task in TASKS:
            threshold = self.thresholds[task]
            stimulus = stimuli[task]
            prob = stimulus / (stimulus + threshold) if (stimulus + threshold) > 0 else 0
            probabilities[task] = prob
        
        # Choose task probabilistically or be inactive
        total_prob = sum(probabilities.values())
        if total_prob == 0:
            self.current_task = None
            return
        
        # Normalize probabilities
        norm_probs = {task: p / total_prob for task, p in probabilities.items()}
        
        # Random choice weighted by normalized probabilities
        r = random.random()
        cumulative = 0.0
        for task, p in norm_probs.items():
            cumulative += p
            if r < cumulative:
                self.current_task = task
                break
        
        # Update model count of bees working on each task
        self.model.task_counts[self.current_task] += 1


class TaskSelSimModel(Model):
    def __init__(self, N):
        super().__init__()
        self.num_agents = N
        self.schedule = RandomActivation(self)
        
        # Initial stimuli for each task, start low
        self.task_stimuli = {task: 0.1 for task in TASKS}
        self.task_counts = {task: 0 for task in TASKS}
        
        # Parameters controlling stimulus dynamics
        self.stimulus_increase_rate = {task: 0.01 for task in TASKS}
        self.stimulus_decrease_rate = {task: 0.1 for task in TASKS}
        
        # Create agents
        for i in range(self.num_agents):
            a = BeeAgent(i, self)
            self.schedule.add(a)
        
        self.datacollector = DataCollector(
            model_reporters={"Foraging Stimulus": lambda m: m.task_stimuli['Foraging'],
                             "Nursing Stimulus": lambda m: m.task_stimuli['Nursing'],
                             "Foraging Count": lambda m: m.task_counts['Foraging'],
                             "Nursing Count": lambda m: m.task_counts['Nursing']}
        )
    
    def step(self):
        # Reset task counts before agents decide
        self.task_counts = {task: 0 for task in TASKS}
        
        self.schedule.step()
        
        # Update stimuli based on task counts
        for task in TASKS:
            # Stimulus increases if task count low, decreases if many bees working on it
            increase = self.stimulus_increase_rate[task]
            decrease = self.stimulus_decrease_rate[task]
            count = self.task_counts[task]
            
            # Update stimulus (simple linear dynamics)
            self.task_stimuli[task] += increase - decrease * count
            # Clamp stimulus to [0,1]
            self.task_stimuli[task] = max(0, min(1, self.task_stimuli[task]))
        
        self.datacollector.collect(self)


if __name__ == "__main__":
    # Run the model for 100 steps
    model = TaskSelSimModel(50)
    for i in range(100):
        model.step()

    # Retrieve data for plotting
    import matplotlib.pyplot as plt
    data = model.datacollector.get_model_vars_dataframe()
    
    plt.plot(data['Foraging Stimulus'], label='Foraging Stimulus')
    plt.plot(data['Nursing Stimulus'], label='Nursing Stimulus')
    plt.plot(data['Foraging Count'], label='Bees Foraging')
    plt.plot(data['Nursing Count'], label='Bees Nursing')
    plt.legend()
    plt.show()