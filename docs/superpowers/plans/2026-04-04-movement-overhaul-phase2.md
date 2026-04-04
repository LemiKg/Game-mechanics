# Movement Overhaul Phase 2: Crouch, Ragdoll, Dodge, Stamina

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add crouch collision resize with head-bonk detection, ragdoll state, dodge/roll committed action, and stamina system.

**Architecture:** Three new files (StaminaComponent, DodgeState, RagdollState) following existing patterns. Modify GroundedState for crouch collision. All new states extend PlayerState.

**Tech Stack:** GDScript, Godot 4.5, CharacterBody3D

---

## Tasks

### Task 1: StaminaComponent
Create `addons/player_control_core/core/stamina_component.gd`

### Task 2: DodgeState  
Create `addons/player_control_core/core/state_machine/dodge_state.gd`

### Task 3: RagdollState
Create `addons/player_control_core/core/state_machine/ragdoll_state.gd`

### Task 4: Crouch collision resize in GroundedState
Modify `addons/player_control_core/core/state_machine/grounded_state.gd`

### Task 5: Register new types in plugin + update scene
Modify plugin registration, update player.tscn

### Task 6: Fix compile errors
Search and fix any references
