# ece191-ros-docker

ROS 2 Docker environments for ECE 191 — includes a **camera node** (DepthAI/OAK) and a **LiDAR node** (Livox MID360).

## Repository Layout

```text
.
├── Dockerfile                        # Camera container (ROS 2 Foxy, ARM64/Jetson)
├── Dockerfile.lidar                  # LiDAR container  (ROS 2 Humble, x86-64/ARM)
├── docker-compose.yml                # Compose file to build/run both containers
├── ece191-ros2-depthai-camera/       # ROS 2 workspace — DepthAI/OAK camera node
│   └── ros2_depthai_package/
└── ece191-ros2-livox-lidar/          # Launch scripts — Livox LiDAR node
    └── launch/
```

## Containers

### Camera (`Dockerfile`)

| Property | Value |
|---|---|
| Base image | `arm64v8/ros:foxy-ros-base-focal` (override with `ROS_BASE_IMAGE`) |
| ROS distro | Foxy |
| Package | `ros2_depthai_package` — publishes `sensor_msgs/msg/Image` from a DepthAI/OAK USB camera |

See [`ece191-ros2-depthai-camera/README.md`](ece191-ros2-depthai-camera/README.md) for full usage.

### LiDAR (`Dockerfile.lidar`)

| Property | Value |
|---|---|
| Base image | `osrf/ros:humble-desktop` |
| ROS distro | Humble |
| Drivers | [Livox-SDK2](https://github.com/Livox-SDK/Livox-SDK2) + [livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2) |
| Tested sensor | Livox MID360 (adaptable to HAP and others) |

See [`ece191-ros2-livox-lidar/README.md`](ece191-ros2-livox-lidar/README.md) for full usage.

## Quick Start

### Build both images

```bash
docker compose build
```

### Run the camera container

```bash
docker compose run --rm camera bash
```

### Run the LiDAR container (MID360, last two digits of serial = `<id>`)

```bash
docker compose run --rm lidar \
  /bin/bash -c "/home/devuser/livox_ws/src/run.sh <id> ros2 launch livox_ros_driver2 rviz_MID360_launch.py"
```

### Record LiDAR data

```bash
docker compose run --rm -v .:/log lidar \
  /bin/bash -c "cd /log && /home/devuser/livox_ws/src/run.sh <id> ros2 launch /home/devuser/livox_ws/src/record_MID360_launch.py"
```

## Prerequisites

- Docker (with Compose v2) installed on the host.
- For the camera: a Luxonis DepthAI/OAK USB camera connected to the host.
- For the LiDAR: a Livox sensor connected over Ethernet; host static IP `192.168.1.5`; sensor IP defaults to `192.168.1.1<last-two-digits-of-serial>` (e.g. serial ending `50` → sensor IP `192.168.1.150`).
- For RViz display forwarding: run `xhost +local:root` on the host first.

## Receiving ROS 2 Messages on the Host

Both containers use `--network=host` so they share the host's network stack. For the host to discover and subscribe to topics published inside a container, **three things must match** between the container and the host terminal:

| Setting | Container value | How to set on the host |
|---|---|---|
| Network | `host` (already set) | — |
| `ROS_DOMAIN_ID` | `0` | `export ROS_DOMAIN_ID=0` |
| `RMW_IMPLEMENTATION` | `rmw_cyclonedds_cpp` | `export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` |

### One-time host setup

Install CycloneDDS for your ROS 2 distro (replace `$ROS_DISTRO` with `foxy`, `humble`, etc.):

```bash
sudo apt install ros-$ROS_DISTRO-rmw-cyclonedds-cpp
```

### Per-terminal host setup

In every terminal where you want to see container topics, run:

```bash
source /opt/ros/$ROS_DISTRO/setup.bash
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
```

### Verify connectivity

While a container is running, check that the host can see its topics:

```bash
ros2 topic list
ros2 topic hz /oak/rgb/image_raw   # camera
ros2 topic hz /livox/lidar         # lidar
```

> **Tip:** To avoid setting these exports in every terminal, add them to your `~/.bashrc`:
> ```bash
> echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc
> echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc
> ```

