import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib.colors import LinearSegmentedColormap
import random
from collections import defaultdict
from IPython.display import HTML

class HoneybeeColony:
    def __init__(self, width=31, height=52, adult_bees=700, larvae=100):
        # Environment dimensions
        self.width = width
        self.height = height
        
        # Initialize environment grid
        self.grid = np.zeros((width, height), dtype=object)
        for x in range(width):
            for y in range(height):
                self.grid[x, y] = {'agents': [], 'nectar': 0.0, 'chemical': 0.0, 
                                  'dance_waggle': 0.0, 'dance_tremble': 0.0, 'contact_stimulus': 0.0,
                                  'light': 0.0, 'is_broodnest': False, 'is_storage': False}
        
        # Define hive areas
        self.entrance_pos = (width // 2, 0)
        self.broodnest_center = (width // 2, height // 2)
        self.storage_center = (width // 2, 3 * height // 4)
        
        # Define broodnest area
        broodnest_radius = min(width, height) // 4
        for x in range(width):
            for y in range(height):
                if ((x - self.broodnest_center[0])**2 + (y - self.broodnest_center[1])**2) < broodnest_radius**2:
                    self.grid[x, y]['is_broodnest'] = True
        
        # Define storage area
        storage_radius = min(width, height) // 5
        for x in range(width):
            for y in range(height):
                if ((x - self.storage_center[0])**2 + (y - self.storage_center[1])**2) < storage_radius**2:
                    self.grid[x, y]['is_storage'] = True
        
        # Initialize light gradient (decreases from entrance)
        for x in range(width):
            for y in range(height):
                # Calculate distance from entrance
                dist = np.sqrt((x - self.entrance_pos[0])**2 + (y - self.entrance_pos[1])**2)
                # Light decreases linearly with distance
                self.grid[x, y]['light'] = max(0, 1 - (dist / (width + height)))
        
        # Initialize agents
        self.agents = []
        self.larvae = []
        self.stats = {'forager': [], 'storer': [], 'nurse': [], 'unemployed': [], 'time': [], 
                     'net_nectar_gain': [], 'total_nectar': [], 'dead_larvae': 0}
        
        # Parameters
        self.diffusion_rate = 0.1  # Rate of chemical diffusion
        self.chemical_decay_rate = 0.01  # Rate of chemical decay
        
        # Create adult bees
        for _ in range(adult_bees):
            x = random.randint(0, width-1)
            y = random.randint(0, height-1)
            bee = AdultBee(self, x, y)
            self.agents.append(bee)
            self.grid[x, y]['agents'].append(bee)
        
        # Create larvae
        for _ in range(larvae):
            # Place larvae in the broodnest area with normal distribution
            while True:
                x = int(np.random.normal(self.broodnest_center[0], broodnest_radius/3))
                y = int(np.random.normal(self.broodnest_center[1], broodnest_radius/3))
                if 0 <= x < width and 0 <= y < height and self.grid[x, y]['is_broodnest']:
                    larva = Larva(self, x, y)
                    self.larvae.append(larva)
                    self.grid[x, y]['agents'].append(larva)
                    break
        
        # External parameters
        self.nectar_source_amount = 10.0  # Amount of nectar at the source
        self.current_step = 0
        
    def place_cage(self, center_x, center_y, radius):
        """Place a virtual cage around an area to prevent bees from entering"""
        self.cage_area = {'center': (center_x, center_y), 'radius': radius, 'active': True}
        
    def remove_cage(self):
        """Remove the virtual cage"""
        if hasattr(self, 'cage_area'):
            self.cage_area['active'] = False
    
    def is_in_cage(self, x, y):
        """Check if a position is within the active cage area"""
        if hasattr(self, 'cage_area') and self.cage_area['active']:
            center_x, center_y = self.cage_area['center']
            radius = self.cage_area['radius']
            return ((x - center_x)**2 + (y - center_y)**2) < radius**2
        return False
    
    def step(self):
        """Perform one simulation step"""
        self.current_step += 1
        
        # 1. Update chemical signals (diffusion and decay)
        self._update_chemicals()
        
        # 2. Update all stimuli from agents
        self._update_stimuli()
        
        # 3. Agents consume nectar
        self._agents_consume()
        
        # 4. Adult agents decide to engage or give up tasks
        self._update_task_decisions()
        
        # 5. Adult agents perform behavior according to their task
        self._perform_behaviors()
        
        # Record statistics
        self._record_stats()
    
    def _update_chemicals(self):
        """Update chemical concentrations: diffusion and decay"""
        # Create new grid for updated chemical values
        new_chemicals = np.zeros((self.width, self.height))
        
        # Current chemical values
        current_chemicals = np.array([[self.grid[x][y]['chemical'] for y in range(self.height)] 
                                       for x in range(self.width)])
        
        # Apply diffusion
        for x in range(self.width):
            for y in range(self.height):
                # Initialize with current value minus decay
                new_value = current_chemicals[x, y] * (1 - self.chemical_decay_rate)
                
                # Add diffusion from neighbors
                neighbors = 0
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.width and 0 <= ny < self.height:
                        new_value += current_chemicals[nx, ny] * self.diffusion_rate
                        neighbors += 1
                
                new_chemicals[x, y] = new_value
        
        # Update grid with new chemical values
        for x in range(self.width):
            for y in range(self.height):
                self.grid[x][y]['chemical'] = new_chemicals[x, y]
    
    def _update_stimuli(self):
        """Update all stimuli from agents"""
        # Reset dance and contact stimuli (these don't persist)
        for x in range(self.width):
            for y in range(self.height):
                self.grid[x][y]['dance_waggle'] = 0.0
                self.grid[x][y]['dance_tremble'] = 0.0
                self.grid[x][y]['contact_stimulus'] = 0.0
        
        # Let all agents emit their stimuli
        for agent in self.agents + self.larvae:
            agent.emit_stimuli()
    
    def _agents_consume(self):
        """All agents consume nectar"""
        for agent in self.agents + self.larvae:
            agent.consume_nectar()
    
    def _update_task_decisions(self):
        """Adult agents decide to engage or give up tasks"""
        for agent in self.agents:
            if isinstance(agent, AdultBee):
                agent.decide_task()
    
    def _perform_behaviors(self):
        """Adult agents perform behavior according to their task"""
        for agent in self.agents:
            if isinstance(agent, AdultBee):
                agent.perform_behavior()
    
    def _record_stats(self):
      """Record statistics about the colony"""
      task_counts = {
          'forager': 0, 
          'storer': 0, 
          'nurse': 0,  # Changed from 'nursing' to 'nurse' to match task name
          'unemployed': 0
      }
      
      for agent in self.agents:
          if isinstance(agent, AdultBee):
              # Ensure the task name matches what's in task_counts
              if agent.task in task_counts:
                  task_counts[agent.task] += 1
              else:
                  # Handle unexpected task names
                  task_counts['unemployed'] += 1
      
      # Rest of the method remains the same...
      total_nectar = sum(self.grid[x][y]['nectar'] for x in range(self.width) for y in range(self.height))
      for agent in self.agents + self.larvae:
          total_nectar += agent.nectar_load
      
      # Calculate net nectar gain since last step
      if len(self.stats['total_nectar']) > 0:
          net_gain = total_nectar - self.stats['total_nectar'][-1]
      else:
          net_gain = 0
      
      self.stats['forager'].append(task_counts['forager'])
      self.stats['storer'].append(task_counts['storer'])
      self.stats['nurse'].append(task_counts['nurse'])  # Changed from 'nursing' to 'nurse'
      self.stats['unemployed'].append(task_counts['unemployed'])
      self.stats['time'].append(self.current_step)
      self.stats['net_nectar_gain'].append(net_gain)
      self.stats['total_nectar'].append(total_nectar)
      
    def plot_stats(self):
        """Plot colony statistics"""
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 12))
        
        # Plot task cohorts
        ax1.plot(self.stats['time'], self.stats['forager'], label='Foragers')
        ax1.plot(self.stats['time'], self.stats['storer'], label='Storers')
        ax1.plot(self.stats['time'], self.stats['nurse'], label='Nurses')
        ax1.plot(self.stats['time'], self.stats['unemployed'], label='Unemployed')
        ax1.set_xlabel('Time steps')
        ax1.set_ylabel('Number of bees')
        ax1.set_title('Division of labor over time')
        ax1.legend()
        ax1.grid(True)
        
        # Plot net nectar gain as moving average
        window_size = 100
        if len(self.stats['net_nectar_gain']) > window_size:
            moving_avg = []
            for i in range(len(self.stats['net_nectar_gain']) - window_size + 1):
                window_avg = sum(self.stats['net_nectar_gain'][i:i+window_size]) / window_size
                moving_avg.append(window_avg)
            ax2.plot(self.stats['time'][window_size-1:], moving_avg)
        else:
            ax2.plot(self.stats['time'], self.stats['net_nectar_gain'])
        
        ax2.set_xlabel('Time steps')
        ax2.set_ylabel('Net nectar gain')
        ax2.set_title('Colony nectar economics')
        ax2.grid(True)
        
        plt.tight_layout()
        plt.show()
    
    def visualize(self):
        """Visualize the current state of the colony"""
        fig, ax = plt.subplots(figsize=(10, 15))
        
        # Create grid for visualization
        visual_grid = np.zeros((self.width, self.height, 4))  # RGBA
        
        # Define colors
        colors = {
            'background': [0.9, 0.9, 0.8, 1.0],  # Light yellow for hive
            'broodnest': [0.95, 0.85, 0.7, 1.0],  # Slightly darker for broodnest
            'storage': [0.85, 0.85, 0.7, 1.0],  # Slightly different for storage
            'entrance': [0.7, 0.7, 0.7, 1.0],  # Gray for entrance
            'chemical': [1.0, 0.0, 0.0, 0.5],  # Red for chemical signals
            'larva': [1.0, 1.0, 0.5, 1.0],  # Yellow for larvae
            'forager': [0.0, 0.0, 0.8, 1.0],  # Blue for foragers
            'storer': [0.0, 0.8, 0.0, 1.0],  # Green for storers
            'nurse': [0.8, 0.0, 0.8, 1.0],  # Purple for nurses
            'unemployed': [0.5, 0.5, 0.5, 1.0]  # Gray for unemployed
        }
        
        # Fill background based on area type
        for x in range(self.width):
            for y in range(self.height):
                cell = self.grid[x][y]
                
                # Base color
                if (x, y) == self.entrance_pos:
                    visual_grid[x, y] = colors['entrance']
                elif cell['is_broodnest']:
                    visual_grid[x, y] = colors['broodnest']
                elif cell['is_storage']:
                    visual_grid[x, y] = colors['storage']
                else:
                    visual_grid[x, y] = colors['background']
                
                # Add chemical intensity
                if cell['chemical'] > 0:
                    chem_intensity = min(1.0, cell['chemical'] / 2.0)  # Scale appropriately
                    visual_grid[x, y] = [
                        visual_grid[x, y, 0] * (1 - chem_intensity) + colors['chemical'][0] * chem_intensity,
                        visual_grid[x, y, 1] * (1 - chem_intensity) + colors['chemical'][1] * chem_intensity,
                        visual_grid[x, y, 2] * (1 - chem_intensity) + colors['chemical'][2] * chem_intensity,
                        1.0
                    ]
        
        # Draw agents
        for agent_list in [self.agents, self.larvae]:
            for agent in agent_list:
                x, y = agent.x, agent.y
                
                if isinstance(agent, Larva):
                    plt.scatter(y, x, color=colors['larva'], s=40, marker='o')
                elif isinstance(agent, AdultBee):
                    color = colors[agent.task]
                    plt.scatter(y, x, color=color, s=20, marker='x')
        
        # Draw cage if active
        if hasattr(self, 'cage_area') and self.cage_area['active']:
            center_x, center_y = self.cage_area['center']
            radius = self.cage_area['radius']
            circle = plt.Circle((center_y, center_x), radius, fill=False, color='black', linestyle='--', linewidth=2)
            ax.add_patch(circle)
        
        # Convert coordinates to match visualization (x is vertical, y is horizontal in imshow)
        transposed_grid = np.transpose(visual_grid, (1, 0, 2))
        
        # Show the hive
        ax.imshow(transposed_grid, origin='lower')
        ax.set_title(f'Honeybee Colony - Step {self.current_step}')
        
        # No ticks needed
        ax.set_xticks([])
        ax.set_yticks([])
        
        # Add legend
        legend_elements = [
            plt.Line2D([0], [0], marker='o', color='w', markerfacecolor=colors['larva'], markersize=10, label='Larva'),
            plt.Line2D([0], [0], marker='x', color=colors['forager'], markersize=10, label='Forager'),
            plt.Line2D([0], [0], marker='x', color=colors['storer'], markersize=10, label='Storer'),
            plt.Line2D([0], [0], marker='x', color=colors['nurse'], markersize=10, label='Nurse'),
            plt.Line2D([0], [0], marker='x', color=colors['unemployed'], markersize=10, label='Unemployed')
        ]
        ax.legend(handles=legend_elements, loc='upper right')
        
        plt.tight_layout()
        plt.show()


class Agent:
    """Base class for all agents in the simulation"""
    def __init__(self, colony, x, y):
        self.colony = colony
        self.x = x
        self.y = y
        self.nectar_load = random.uniform(0.1, 0.3)  # Initial random nectar load
        self.alive = True
    
    def consume_nectar(self):
        """Consume nectar based on metabolism"""
        pass
    
    def emit_stimuli(self):
        """Emit stimuli that affect other agents"""
        pass


class AdultBee(Agent):
    """Adult honeybee agent that can perform various tasks"""
    def __init__(self, colony, x, y):
        super().__init__(colony, x, y)
        self.task = 'unemployed'  # Initial task
        self.nectar_load = random.uniform(0.2, 1.0)  # Initial random nectar load
        self.max_nectar_capacity = 1.0
        
        # Task-specific consumption rates
        self.consumption_rate_low = 0.0004  # Regular consumption
        self.consumption_rate_high = 0.001  # Flying (foraging) consumption
        
        # Task engagement parameters
        self.task_thresholds = {
            'foraging': random.uniform(0.0, 1.0),  # Theta_foraging
            'storing': random.uniform(0.0, 1.0),    # Theta_storing
            'nursing': random.uniform(0.0, 1.0)     # Theta_nursing
        }
        
        # Parameters for task switching
        self.task_giving_up_prob = {
            'foraging': 0.001,
            'storing': 0.005,
            'nursing': 0.005
        }
        
        # Task reinforcement parameters
        self.xi = 0.1  # Decrease threshold when engaging in task
        self.phi = 0.001  # Increase threshold when not engaging in task
        
        # Foraging-specific parameters
        self.flight_time_remaining = 0
        self.searching_for_storer_time = 0
        self.is_dancing = False
        self.dance_type = None
        self.dance_time_remaining = 0
        
        # Nursing-specific parameters
        self.feeding_larva = None
        self.feeding_time_remaining = 0
        
        # Movement
        self.heading = random.uniform(0, 2*np.pi)  # Random initial heading
        self.speed = 1  # Movement speed
    
    def consume_nectar(self):
        """Consume nectar based on task"""
        if not self.alive:
            return
            
        if self.task == 'foraging' and self.flight_time_remaining > 0:
            # Flying foragers consume more
            self.nectar_load -= self.consumption_rate_high
        else:
            # Regular consumption
            self.nectar_load -= self.consumption_rate_low
        
        # Check if bee died due to starvation
        if self.nectar_load <= 0:
            self.die()
    
    def die(self):
        """Handle bee death"""
        self.alive = False
        if self in self.colony.grid[self.x][self.y]['agents']:
            self.colony.grid[self.x][self.y]['agents'].remove(self)
        if self in self.colony.agents:
            self.colony.agents.remove(self)
    
    def move(self, target_x=None, target_y=None):
        """Move the bee according to its current heading or towards a target"""
        if not self.alive or self.colony.is_in_cage(self.x, self.y):
            return False
        
        old_x, old_y = self.x, self.y
        
        if target_x is not None and target_y is not None:
            # Move towards target
            dx = target_x - self.x
            dy = target_y - self.y
            distance = max(0.1, np.sqrt(dx*dx + dy*dy))
            
            # Normalize and scale by speed
            step_x = (dx / distance) * self.speed
            step_y = (dy / distance) * self.speed
            
            # Apply movement
            new_x = int(round(self.x + step_x))
            new_y = int(round(self.y + step_y))
        else:
            # Random movement in current heading
            new_x = int(round(self.x + self.speed * np.cos(self.heading)))
            new_y = int(round(self.y + self.speed * np.sin(self.heading)))
            
            # Small random adjustment to heading
            self.heading += random.uniform(-0.5, 0.5)
        
        # Check boundaries
        new_x = max(0, min(self.colony.width - 1, new_x))
        new_y = max(0, min(self.colony.height - 1, new_y))
        
        # Check if new position is in cage
        if self.colony.is_in_cage(new_x, new_y):
            # Change heading if hitting cage
            self.heading = random.uniform(0, 2*np.pi)
            return False
        
        # Update position
        if (new_x, new_y) != (old_x, old_y):
            # Remove from old position
            if self in self.colony.grid[old_x][old_y]['agents']:
                self.colony.grid[old_x][old_y]['agents'].remove(self)
            
            # Add to new position
            self.x, self.y = new_x, new_y
            self.colony.grid[new_x][new_y]['agents'].append(self)
            return True
        
        return False
    
    def emit_stimuli(self):
        """Emit stimuli based on task and state"""
        if not self.alive:
            return
            
        # Foragers may emit dance stimuli
        if self.is_dancing and self.dance_time_remaining > 0:
            self.emit_dance_stimulus()
            self.dance_time_remaining -= 1
            if self.dance_time_remaining <= 0:
                self.is_dancing = False
        
        # Returning foragers emit contact stimulus to attract storer bees
        if self.task == 'foraging' and self.searching_for_storer_time > 0:
            self.emit_contact_stimulus()
    
    def emit_dance_stimulus(self):
        """Emit dance stimuli (waggle or tremble)"""
        dance_range = 3  # Range of dance stimulus
        dance_intensity = 1.0  # Base intensity
        
        for dx in range(-dance_range, dance_range + 1):
            for dy in range(-dance_range, dance_range + 1):
                nx, ny = self.x + dx, self.y + dy
                
                if 0 <= nx < self.colony.width and 0 <= ny < self.colony.height:
                    # Intensity decreases with distance
                    distance = max(1, np.sqrt(dx*dx + dy*dy))
                    intensity = dance_intensity / distance
                    
                    if self.dance_type == 'waggle':
                        self.colony.grid[nx][ny]['dance_waggle'] += intensity
                    elif self.dance_type == 'tremble':
                        self.colony.grid[nx][ny]['dance_tremble'] += intensity
    
    def emit_contact_stimulus(self):
        """Emit contact stimulus to attract storer bees"""
        contact_range = 1  # Range of contact stimulus
        contact_intensity = 1.0  # Base intensity
        
        for dx in range(-contact_range, contact_range + 1):
            for dy in range(-contact_range, contact_range + 1):
                nx, ny = self.x + dx, self.y + dy
                
                if 0 <= nx < self.colony.width and 0 <= ny < self.colony.height:
                    self.colony.grid[nx][ny]['contact_stimulus'] += contact_intensity
    
    def decide_task(self):
        """Decide whether to engage in a task or give up current task"""
        if not self.alive:
            return
            
        # If currently employed, check if should give up task
        if self.task != 'unemployed':
            if random.random() < self.task_giving_up_prob[self.task]:
                self.task = 'unemployed'
                # Reset task-specific state
                self.feeding_larva = None
                self.feeding_time_remaining = 0
                self.flight_time_remaining = 0
                self.searching_for_storer_time = 0
                self.is_dancing = False
                self.dance_time_remaining = 0
        
        # If unemployed, check stimuli to decide on task
        if self.task == 'unemployed':
            # Get local stimuli
            local_chemical = self.colony.grid[self.x][self.y]['chemical']
            local_waggle = self.colony.grid[self.x][self.y]['dance_waggle']
            local_tremble = self.colony.grid[self.x][self.y]['dance_tremble']
            local_contact = self.colony.grid[self.x][self.y]['contact_stimulus']
            
            # Calculate probabilities for each task
            p_nursing = self._calculate_probability(local_chemical, 'nursing')
            p_storing = self._calculate_probability(local_contact + local_tremble, 'storing')
            p_foraging = self._calculate_probability(local_waggle, 'foraging')
            
            # Check if any stimulus exceeds threshold
            rand = random.random()
            
            # Choose task with highest probability that exceeds random threshold
            task_probs = [
                ('nursing', p_nursing),
                ('storing', p_storing),
                ('foraging', p_foraging)
            ]
            
            random.shuffle(task_probs)  # Shuffle to avoid bias in equal probabilities
            
            for task, prob in task_probs:
                if rand < prob:
                    # Engage in this task
                    self.task = task
                    
                    # Reinforce threshold for this task (make more likely in future)
                    self.task_thresholds[task] = max(0, self.task_thresholds[task] - self.xi)
                    
                    # Initialize task-specific state
                    if task == 'foraging':
                        # Foragers immediately head to the entrance
                        pass
                    elif task == 'storing':
                        # Storers head to entrance to wait for foragers
                        pass
                    elif task == 'nursing':
                        # Nurses look for hungry larvae
                        pass
                    
                    break
            
            # If still unemployed, increment all thresholds slightly
            if self.task == 'unemployed':
                for task in self.task_thresholds:
                    self.task_thresholds[task] = min(1.0, self.task_thresholds[task] + self.phi)
    
    def _calculate_probability(self, stimulus, task):
        """Calculate probability of engaging in a task based on stimulus and threshold"""
        if stimulus <= 0:
            return 0.0
        
        n = 2  # Non-linearity parameter
        theta = self.task_thresholds[task]
        
        # Threshold response function from the paper
        return (stimulus ** n) / ((stimulus ** n) + (theta ** n))
    
    def perform_behavior(self):
        """Perform behavior based on current task"""
        if not self.alive:
            return
            
        if self.task == 'unemployed':
            self._behavior_unemployed()
        elif self.task == 'foraging':
            self._behavior_foraging()
        elif self.task == 'storing':
            self._behavior_storing()
        elif self.task == 'nursing':
            self._behavior_nursing()
    
    def _behavior_unemployed(self):
        """Behavior for unemployed bees: random movement"""
        self.move()  # Random movement
    
    def _behavior_foraging(self):
        """Behavior for forager bees"""
        if self.flight_time_remaining > 0:
            # Currently flying to/from nectar source
            self.flight_time_remaining -= 1
            
            if self.flight_time_remaining == 0:
                if self.nectar_load < 0.3:
                    # Returned from nectar source with full load
                    self.nectar_load = self.max_nectar_capacity
                    # Start searching for a storer bee
                    self.searching_for_storer_time = 1
                    # Move to entrance
                    self.x, self.y = self.colony.entrance_pos
                else:
                    # Going back to forage again after unloading/dancing
                    self.flight_time_remaining = 20  # Time to fly to source
        
        elif self.searching_for_storer_time > 0:
            # Looking for storer bee to unload
            found_storer = False
            
            # Check if there are storer bees nearby
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    nx, ny = self.x + dx, self.y + dy
                    if 0 <= nx < self.colony.width and 0 <= ny < self.colony.height:
                        for agent in self.colony.grid[nx][ny]['agents']:
                            if isinstance(agent, AdultBee) and agent.task == 'storing' and agent.nectar_load < 0.7:
                                # Transfer nectar to storer
                                transfer_amount = min(self.nectar_load, agent.max_nectar_capacity - agent.nectar_load)
                                agent.nectar_load += transfer_amount
                                self.nectar_load -= transfer_amount
                                found_storer = True
                                break
                    if found_storer:
                        break
                if found_storer:
                    break
            
            if found_storer:
                # Decide whether to dance based on search time
                self.searching_for_storer_time = 0
                
                if self.searching_for_storer_time <= 20:
                    # Short wait = waggle dance to recruit more foragers
                    self.is_dancing = True
                    self.dance_type = 'waggle'
                    self.dance_time_remaining = 10
                elif self.searching_for_storer_time >= 50:
                    # Long wait = tremble dance to recruit more storers
                    self.is_dancing = True
                    self.dance_type = 'tremble'
                    self.dance_time_remaining = 10
                
                # After unloading, move randomly for a while
                self.move()
            else:
                # Continue searching
                self.searching_for_storer_time += 1
                self.move()
        
        else:
            # Start foraging trip by flying to source
            self.flight_time_remaining = 20  # Time to fly to source
            self.move()
    
    def _behavior_storing(self):
        """Behavior for storer bees"""
        if self.nectar_load > 0:
            # Has nectar to store - move to storage area
            storage_center_x, storage_center_y = self.colony.storage_center
            
            # Check if reached storage area
            if ((self.x - storage_center_x)**2 + (self.y - storage_center_y)**2) < 25:  # Within 5 units
                # Deposit nectar in storage
                self.colony.grid[self.x][self.y]['nectar'] += self.nectar_load
                self.nectar_load = 0
            else:
                # Move towards storage area
                self.move(storage_center_x, storage_center_y)
        else:
            # No nectar - move to entrance to wait for foragers
            entrance_x, entrance_y = self.colony.entrance_pos
            
            # Check if at entrance
            if (self.x, self.y) == (entrance_x, entrance_y):
                # Wait at entrance
                pass
            else:
                # Move towards entrance
                self.move(entrance_x, entrance_y)
    
    def _behavior_nursing(self):
        """Behavior for nurse bees"""
        if self.feeding_larva is not None and self.feeding_time_remaining > 0:
            # Currently feeding a larva
            self.feeding_time_remaining -= 1
            
            if self.feeding_time_remaining == 0:
                # Finished feeding
                self.feeding_larva = None
                self.move()  # Move away after feeding
        else:
            # Look for hungry larvae
            best_larva = None
            best_chemical = 0
            
            # Check current cell first
            for agent in self.colony.grid[self.x][self.y]['agents']:
                if isinstance(agent, Larva) and agent.is_hungry():
                    best_larva = agent
                    best_chemical = agent.get_hunger_stimulus()
                    break
            
            # If no larva in current cell, check nearby cells
            if best_larva is None:
                for dx in range(-3, 4):
                    for dy in range(-3, 4):
                        nx, ny = self.x + dx, self.y + dy
                        if 0 <= nx < self.colony.width and 0 <= ny < self.colony.height:
                            for agent in self.colony.grid[nx][ny]['agents']:
                                if isinstance(agent, Larva) and agent.is_hungry():
                                    current_chemical = agent.get_hunger_stimulus()
                                    if current_chemical > best_chemical:
                                        best_larva = agent
                                        best_chemical = current_chemical
            
            if best_larva is not None and self.nectar_load > 0.1:
                # Found a hungry larva - move to it if not already there
                if (self.x, self.y) != (best_larva.x, best_larva.y):
                    self.move(best_larva.x, best_larva.y)
                else:
                    # Start feeding
                    self.feeding_larva = best_larva
                    self.feeding_time_remaining = 5  # Feeding duration
                    
                    # Transfer nectar to larva
                    transfer_amount = min(0.1, self.nectar_load, 
                                         best_larva.max_nectar_capacity - best_larva.nectar_load)
                    best_larva.nectar_load += transfer_amount
                    self.nectar_load -= transfer_amount
            else:
                # No hungry larva found or not enough nectar - move randomly
                self.move()


class Larva(Agent):
    """Larva agent that needs to be fed by nurse bees"""
    def __init__(self, colony, x, y):
        super().__init__(colony, x, y)
        self.nectar_load = random.uniform(0.1, 0.33)  # Initial random nectar load
        self.max_nectar_capacity = 0.33
        self.consumption_rate = 0.0004  # Larval consumption rate
        self.hunger_threshold = 0.25  # Below this, larva is hungry
    
    def consume_nectar(self):
        """Larva consumes nectar"""
        if not self.alive:
            return
            
        self.nectar_load -= self.consumption_rate
        
        # Check if larva died due to starvation
        if self.nectar_load <= 0:
            self.die()
    
    def die(self):
        """Handle larva death"""
        self.alive = False
        if self in self.colony.grid[self.x][self.y]['agents']:
            self.colony.grid[self.x][self.y]['agents'].remove(self)
        if self in self.colony.larvae:
            self.colony.larvae.remove(self)
        self.colony.stats['dead_larvae'] += 1
    
    def is_hungry(self):
        """Check if larva is hungry (emitting chemical signal)"""
        return self.alive and self.nectar_load < self.hunger_threshold
    
    def get_hunger_stimulus(self):
        """Get the hunger stimulus intensity based on nectar level"""
        if not self.is_hungry():
            return 0.0
        
        # Stimulus intensity scales linearly from 1 to 0 as nectar goes from 0 to hunger_threshold
        return 1.0 - (self.nectar_load / self.hunger_threshold)
    
    def emit_stimuli(self):
        """Emit chemical hunger signal if hungry"""
        if self.is_hungry():
            # Add to chemical concentration in this cell
            self.colony.grid[self.x][self.y]['chemical'] += self.get_hunger_stimulus()


# Simulation functions
def run_simulation(steps=500, visualize_every=10):
    """Run the simulation with visualization"""
    colony = HoneybeeColony(adult_bees=700, larvae=100)
    
    # Animation setup
    fig, ax = plt.subplots(figsize=(10, 15))
    im = ax.imshow(np.zeros((colony.height, colony.width, 4)), origin='lower')
    ax.set_title('Honeybee Colony - Step 0')
    ax.set_xticks([])
    ax.set_yticks([])
    
    def init():
        """Initialization function for animation"""
        im.set_array(np.zeros((colony.height, colony.width, 4)))
        return (im,)
    
    def update(frame):
        """Update function for animation"""
        colony.step()
        
        if frame % visualize_every == 0 or frame == steps-1:
            # Update visualization
            visual_grid = np.zeros((colony.width, colony.height, 4))
            
            # Fill background based on area type
            for x in range(colony.width):
                for y in range(colony.height):
                    cell = colony.grid[x][y]
                    
                    # Base color
                    if (x, y) == colony.entrance_pos:
                        visual_grid[x, y] = [0.7, 0.7, 0.7, 1.0]  # Gray for entrance
                    elif cell['is_broodnest']:
                        visual_grid[x, y] = [0.95, 0.85, 0.7, 1.0]  # Broodnest
                    elif cell['is_storage']:
                        visual_grid[x, y] = [0.85, 0.85, 0.7, 1.0]  # Storage
                    else:
                        visual_grid[x, y] = [0.9, 0.9, 0.8, 1.0]  # Light yellow for hive
                    
                    # Add chemical intensity
                    if cell['chemical'] > 0:
                        chem_intensity = min(1.0, cell['chemical'] / 2.0)
                        visual_grid[x, y] = [
                            visual_grid[x, y, 0] * (1 - chem_intensity) + 1.0 * chem_intensity,
                            visual_grid[x, y, 1] * (1 - chem_intensity),
                            visual_grid[x, y, 2] * (1 - chem_intensity),
                            1.0
                        ]
            
            # Convert coordinates to match visualization
            transposed_grid = np.transpose(visual_grid, (1, 0, 2))
            im.set_array(transposed_grid)
            ax.set_title(f'Honeybee Colony - Step {frame}')
        
        return (im,)
    
    # Create animation with blit=False to avoid the resize_id issue
    ani = animation.FuncAnimation(
        fig, update, frames=steps,
        init_func=init, interval=50, blit=False
    )
    
    plt.close()
    
    # Show animation
    try:
        return HTML(ani.to_jshtml())
    except ImportError:
        print("Animation output requires IPython.display")
        return ani


def run_experiment():
    """Run the experiment from the paper"""
    # Create colony
    colony = HoneybeeColony(adult_bees=700, larvae=100)
    
    # Let colony reach equilibrium (10000 steps)
    for _ in range(1000):  # Reduced for demonstration
        colony.step()
    
    # Save initial state (simplified)
    initial_state = {
        'foragers': colony.stats['forager'][-1],
        'storers': colony.stats['storer'][-1],
        'nurses': colony.stats['nurse'][-1],
        'unemployed': colony.stats['unemployed'][-1],
        'nectar': colony.stats['total_nectar'][-1]
    }
    
    # Perform perturbations
    perturbations = [
        ('remove_larvae', 25),  # Remove 25 larvae
        ('remove_larvae', 50),  # Remove 50 larvae
        ('add_larvae', 25),     # Add 25 larvae
        ('remove_bees', 175),   # Remove 175 bees (25%)
        ('cage_experiment', None)  # Cage experiment
    ]
    
    results = {}
    
    for perturbation, amount in perturbations:
        # Reset to initial state
        colony = HoneybeeColony(adult_bees=700, larvae=100)
        for _ in range(1000):  # Reduced for demonstration
            colony.step()
        
        # Apply perturbation
        if perturbation == 'remove_larvae':
            # Randomly remove larvae
            for _ in range(amount):
                if colony.larvae:
                    larva = random.choice(colony.larvae)
                    larva.die()
        
        elif perturbation == 'add_larvae':
            # Add new larvae
            for _ in range(amount):
                while True:
                    x = int(np.random.normal(colony.broodnest_center[0], 5))
                    y = int(np.random.normal(colony.broodnest_center[1], 5))
                    if 0 <= x < colony.width and 0 <= y < colony.height and colony.grid[x][y]['is_broodnest']:
                        larva = Larva(colony, x, y)
                        colony.larvae.append(larva)
                        colony.grid[x][y]['agents'].append(larva)
                        break
        
        elif perturbation == 'remove_bees':
            # Randomly remove bees
            for _ in range(amount):
                if colony.agents:
                    bee = random.choice(colony.agents)
                    bee.die()
        
        elif perturbation == 'cage_experiment':
            # Place cage around center broodnest
            colony.place_cage(colony.broodnest_center[0], colony.broodnest_center[1], 5)
        
        # Run simulation after perturbation
        post_stats = {
            'forager': [],
            'storer': [],
            'nurse': [],
            'unemployed': [],
            'total_nectar': []
        }
        
        for _ in range(500):  # Reduced for demonstration
            colony.step()
            
            # Record stats
            post_stats['forager'].append(colony.stats['forager'][-1])
            post_stats['storer'].append(colony.stats['storer'][-1])
            post_stats['nurse'].append(colony.stats['nurse'][-1])
            post_stats['unemployed'].append(colony.stats['unemployed'][-1])
            post_stats['total_nectar'].append(colony.stats['total_nectar'][-1])
            
            # For cage experiment, remove cage after some time
            if perturbation == 'cage_experiment' and colony.current_step == 1250:
                colony.remove_cage()
        
        # Calculate changes
        results[perturbation + (f'_{amount}' if amount is not None else '')] = {
            'initial': initial_state,
            'final': {
                'foragers': np.mean(post_stats['forager'][-100:]),
                'storers': np.mean(post_stats['storer'][-100:]),
                'nurses': np.mean(post_stats['nurse'][-100:]),
                'unemployed': np.mean(post_stats['unemployed'][-100:]),
                'nectar': np.mean(post_stats['total_nectar'][-100:])
            },
            'change': {
                'foragers': (np.mean(post_stats['forager'][-100:]) - initial_state['foragers']) / initial_state['foragers'],
                'storers': (np.mean(post_stats['storer'][-100:]) - initial_state['storers']) / initial_state['storers'],
                'nurses': (np.mean(post_stats['nurse'][-100:]) - initial_state['nurses']) / initial_state['nurses'],
                'unemployed': (np.mean(post_stats['unemployed'][-100:]) - initial_state['unemployed']) / initial_state['unemployed'],
                'nectar': (np.mean(post_stats['total_nectar'][-100:]) - initial_state['nectar']) / initial_state['nectar']
            }
        }
    
    return results


def plot_results(results):
    """Plot the results of the experiment"""
    perturbations = list(results.keys())
    
    # Prepare data
    metrics = ['foragers', 'storers', 'nurses', 'unemployed', 'nectar']
    changes = {metric: [results[p]['change'][metric] for p in perturbations for metric in metrics]}
    
    # Plot
    fig, axes = plt.subplots(2, 3, figsize=(18, 10))
    axes = axes.flatten()
    
    for i, metric in enumerate(metrics):
        ax = axes[i]
        values = [results[p]['change'][metric] for p in perturbations]
        ax.bar(perturbations, values)
        ax.set_title(f'Change in {metric}')
        ax.set_ylabel('Relative change')
        ax.tick_params(axis='x', rotation=45)
    
    # Remove empty subplot
    fig.delaxes(axes[-1])
    
    plt.tight_layout()
    plt.show()


# Main execution
if __name__ == "__main__":
    # Run simple simulation with visualization
    print("Running simulation with visualization...")
    animation = run_simulation(steps=500, visualize_every=10)
    
    # Run experiment from paper
    print("\nRunning experiment...")
    results = run_experiment()
    
    # Plot results
    print("\nPlotting results...")
    plot_results(results)
    
    # Show animation (in environments that support it)
    try:
        from IPython.display import display
        display(animation)
    except ImportError:
        print("Animation output requires IPython.display")