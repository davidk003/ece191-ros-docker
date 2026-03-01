# ece191-ros2-livox-lidar

Docker environment for running ROS 2 drivers for Livox LiDAR sensors, with a focus on the MID360 model.

Based on [tedsamu/livox-ros2-docker](https://github.com/tedsamu/livox-ros2-docker).

## Overview

This directory contains convenience launch scripts for the Livox LiDAR Docker container. The container is built using `Dockerfile.lidar` in the repository root and includes:

- **ROS 2 Humble** with [Livox-SDK2](https://github.com/Livox-SDK/Livox-SDK2) and [livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2)
- [rmw_cyclonedds](https://github.com/ros2/rmw_cyclonedds) for improved distributed-system middleware
- [imu-tools](https://github.com/CCNYRoboticsLab/imu_tools/tree/humble) for IMU visualization in RViz2

## Repository Layout

```text
.
└── launch/
    ├── run.sh                    # Convenience script: sources workspaces and runs a command
    ├── record_MID360_launch.py   # Launch + record all /livox/* topics (MID360)
    └── record_HAP_launch.py      # Launch + record all /livox/* topics (HAP)
```

## Prerequisites

- Docker installed on the host machine.
- Livox sensor connected and host network configured with a static IP of `192.168.1.5`. The sensor IP defaults to `192.168.1.1<last-two-digits-of-serial>` (e.g. serial ending `50` → sensor IP `192.168.1.150`).
- X11 display forwarding for RViz (`xhost +local:root` if needed).

## Building the Image

From the repository root:

```bash
docker build -f Dockerfile.lidar -t ece191/lidar:humble .
```

Or using Docker Compose:

```bash
docker compose build lidar
```

## Running the Container

### View live LiDAR data in RViz (MID360)

Replace `<sensor-id>` with the last two digits of the sensor serial number:

```bash
docker run --rm -it --privileged --network=host \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  --name livox_container ece191/lidar:humble \
  /bin/bash -c "/home/devuser/livox_ws/src/run.sh <sensor-id> ros2 launch livox_ros_driver2 rviz_MID360_launch.py"
```

### Record raw data (PointCloud2 + IMU)

```bash
docker run --rm -it --privileged --network=host \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v .:/log \
  --name livox_container ece191/lidar:humble \
  /bin/bash -c "cd /log && /home/devuser/livox_ws/src/run.sh <sensor-id> ros2 launch /home/devuser/livox_ws/src/record_MID360_launch.py"
```

### Interactive shell

```bash
docker run --rm -it --privileged --network=host \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  --name livox_container ece191/lidar:humble
```

## Launch Files and Scripts

- `launch/run.sh`: Sources ROS 2 workspaces, then runs the given command. If the first argument is a number, it is treated as the sensor ID and used to set the correct sensor IP address in the MID360 config file.
- `launch/record_MID360_launch.py`: Launches the Livox driver and records all `/livox/*` topics (MID360).
- `launch/record_HAP_launch.py`: Launches the Livox driver and records all `/livox/*` topics (HAP).

## Notes

- The container uses `--network=host` and `--privileged` to allow direct access to the Livox sensor over Ethernet.
- Development and testing target Ubuntu with X11 display forwarding.
