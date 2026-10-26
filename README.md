# Hyprland Ricing

A personal Hyprland desktop configuration built around **Quickshell**, with matching **Kitty** terminal settings and a graphical configuration workflow for Hyprland.

This setup was put together over a weekend and is intended to provide a cohesive, lightweight desktop environment that is easy to understand and customize.

## Overview

The configuration combines:

- **Hyprland** as the Wayland compositor and window manager.
- **Quickshell** for the desktop shell, widgets, panels, and graphical controls.
- **Kitty** as the terminal emulator, configured to match the current desktop theme.
- **Hyprland GUI configuration** for adjusting compositor and desktop preferences without editing every setting manually.

## Current Theme

The current theme is shared across the desktop shell, Kitty, and Hyprland-facing UI so that the environment feels consistent across applications.

Theme-related settings are organized around the Quickshell configuration and are reflected in the Kitty configuration. If you want to create a variation of the theme, update the shared colors, backgrounds, typography, and UI styling in those configuration files and then restart or reload the affected components.

## Quickshell

Quickshell provides the graphical layer of the setup. It is used for the desktop experience surrounding Hyprland, including the shell and its interactive UI elements.

Typical responsibilities of the Quickshell configuration include:

- Desktop panels and status information.
- Application launching and navigation.
- Workspace and window-related controls.
- Theme colors, spacing, borders, and visual styling.
- Interactive controls for commonly used desktop actions.

Quickshell is the main visual entry point for this ricing, while Hyprland remains responsible for compositing, windows, workspaces, and keyboard-driven behavior.

## Kitty Configuration

Kitty is configured as the terminal for this setup and follows the current desktop theme. The configuration is intended to keep the terminal visually aligned with Quickshell and the Hyprland GUI.

Kitty settings may include:

- Background and foreground colors.
- ANSI color palette.
- Font and font size.
- Window padding and appearance.
- Cursor and selection styling.
- Transparency or other visual effects, where supported by the current setup.

## Hyprland GUI Configuration

The Hyprland GUI configuration provides a graphical way to manage the compositor and desktop settings used by this setup. It complements the text-based Hyprland configuration by making common options easier to discover and change.

Use the GUI configuration for settings such as:

- Monitor and display behavior.
- Gaps, borders, and window decoration.
- Animations and visual effects.
- Workspace behavior.
- Keybindings and input preferences.
- Startup applications and environment options.

Changes made through the GUI should be reviewed alongside the main Hyprland configuration so that generated or edited settings do not conflict with manually maintained options.

## Design Goals

This configuration aims to be:

- **Cohesive:** Quickshell, Kitty, and Hyprland share the same visual direction.
- **Lightweight:** The setup focuses on a small number of focused components.
- **Customizable:** Settings remain accessible for both graphical and manual editing.
- **Practical:** The desktop should look good while remaining useful for everyday work.

## Getting Started

1. Install Hyprland, Quickshell, Kitty, and the other dependencies used by your system.
2. Back up your existing configuration files.
3. Clone this repository.
4. Copy or link the relevant configuration files into your user configuration directory, usually `~/.config/`.
5. Start Quickshell and Hyprland, then open Kitty to verify that the theme is applied consistently.
6. Use the Hyprland GUI configuration to adjust compositor settings to your hardware and workflow.

> **Note:** Configuration paths and dependencies can vary by distribution. Review the files in this repository before replacing an existing setup.

## Status

This is a personal, evolving ricing project. The configuration may change as the Quickshell interface, Kitty theme, and Hyprland GUI settings are refined.
