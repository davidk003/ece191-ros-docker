# ece191-ros-docker

ROS 2 Docker environments for ECE 191 — includes a **camera node** (DepthAI/OAK) and a **LiDAR node** (Livox MID360).

## Repository Layout

```text
.
├── Dockerfile                        # Camera container (ROS 2 Foxy, ARM64/Jetson)
├── Dockerfile.lidar                  # LiDAR container  (ROS 2 Humble, x86-64/ARM)
├── docker-compose.yml                # Compose file to build/run both containers
├── docker-compose.arm64.yml          # ARM64 override for Jetson AGX Xavier builds
├── verify_nodes.sh                   # Script to verify both nodes are broadcasting
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
| Base image | `osrf/ros:humble-desktop` (default compose build) |
| ARM64 override | `arm64v8/ros:humble-perception-jammy` via `docker-compose.arm64.yml`; `rviz2` is installed explicitly in `Dockerfile.lidar` |
| ROS distro | Humble |
| Drivers | [Livox-SDK2](https://github.com/Livox-SDK/Livox-SDK2) + [livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2) |
| Tested sensor | Livox MID360 (adaptable to HAP and others) |

See [`ece191-ros2-livox-lidar/README.md`](ece191-ros2-livox-lidar/README.md) for full usage.

## Quick Start

### Build both images

```bash
docker compose build
```

### Build for ARM64 / Jetson AGX Xavier

Use the provided ARM64 override file so that native ARM64 base images are used
for both containers (no QEMU emulation required when building on a Jetson):

```bash
docker compose -f docker-compose.yml -f docker-compose.arm64.yml build
docker compose -f docker-compose.yml -f docker-compose.arm64.yml up
```

### Run the camera container

```bash
docker compose run --rm camera bash
```

### Run the camera container manually in the background

This is the direct detached flow the updated launcher uses internally:

```bash
docker compose -f docker-compose.yml -f docker-compose.arm64.yml build camera
docker compose -f docker-compose.yml -f docker-compose.arm64.yml run --rm -d \
  --name last-try-camera \
  camera /bin/bash -lc '/ws/run.sh'
```

Useful follow-up commands:

```bash
docker logs --tail 50 last-try-camera
docker rm -f last-try-camera
```

### Foxy host + camera one-command launcher

`launch_camera_foxy_host.sh` wraps the camera startup flow:

- builds the `camera` image by default before each launch
- removes any existing container with the same name
- starts the camera publisher container in the background as `last-try-camera`
- waits for the Foxy host to discover the camera topic
- attempts `ros2 topic hz <topic>` on the host, but only warns if that sampler is flaky
- keeps the terminal attached so `Ctrl-C` or closing the terminal stops and removes the container

```bash
./launch_camera_foxy_host.sh
```

It defaults to:

- host ROS distro: `foxy`
- topic: `/oak/rgb/image_raw`
- startup wait: `30` seconds
- host verification middleware: `rmw_cyclonedds_cpp`
- container name: `last-try-camera`
- build policy: `always`

Useful overrides:

```bash
CAMERA_TOPIC=/oak/rgb/image_raw ./launch_camera_foxy_host.sh
BUILD_POLICY=never ./launch_camera_foxy_host.sh
STARTUP_TIMEOUT=45 HZ_TIMEOUT=15 ./launch_camera_foxy_host.sh
CAMERA_CONTAINER_NAME=my-camera ./launch_camera_foxy_host.sh
HOST_RMW_IMPLEMENTATION=rmw_cyclonedds_cpp ./launch_camera_foxy_host.sh
```

On success the script keeps running in the foreground after verification. Press
`Ctrl-C` or close the terminal to stop and clean up the camera container.

### Run the LiDAR container (MID360, last two digits of serial = `<id>`)

```bash
docker compose run --rm lidar \
  /bin/bash -c "/home/devuser/livox_ws/src/run.sh <id> ros2 launch livox_ros_driver2 rviz_MID360_launch.py"
```

### Foxy host + Humble LiDAR (no RViz in container, PointCloud2 output)

Use this when your host ROS 2 install is Foxy but the LiDAR container is Humble.
This publishes standard `sensor_msgs/msg/PointCloud2` so Foxy tools can subscribe.

#### One-command launcher

`launch_lidar_foxy_host.sh` wraps the full startup/verification flow:

- builds the `lidar` image if `ece191/lidar:humble` is not present yet
- starts the Humble LiDAR publisher in the container
- waits for the Foxy host to discover the LiDAR topic
- runs `ros2 topic echo <topic>` long enough to capture one full Foxy-compatible message on the host

```bash
./launch_lidar_foxy_host.sh <id>
```

It defaults to:

- host ROS distro: `foxy`
- topic: `/livox/lidar`
- host IP for the Livox config: `192.168.1.50`
- startup wait: `30` seconds

Useful overrides:

```bash
LIVOX_HOST_IP=192.168.1.60 ./launch_lidar_foxy_host.sh <id>
LIDAR_TOPIC=/livox/lidar HOST_ROS_DISTRO=foxy ./launch_lidar_foxy_host.sh <id>
BUILD_POLICY=always ./launch_lidar_foxy_host.sh <id>
STARTUP_TIMEOUT=45 ./launch_lidar_foxy_host.sh <id>
```

On success the script keeps running in the foreground after verification. Press
`Ctrl-C` or close the terminal to stop and clean up the LiDAR container.

#### Manual commands

```bash
# Rebuild after pulling changes (adds pointcloud_MID360_launch.py)
docker compose -f docker-compose.yml -f docker-compose.arm64.yml build --no-cache lidar
```

```bash
# Terminal A: launch LiDAR publisher in container
docker compose -f docker-compose.yml -f docker-compose.arm64.yml run --rm \
  -e LIVOX_HOST_IP=192.168.1.50 \
  lidar /bin/bash -c "/home/devuser/livox_ws/src/run.sh <id> ros2 launch /home/devuser/livox_ws/src/pointcloud_MID360_launch.py"
```

```bash
# Terminal B (host): subscribe from Foxy
source /opt/ros/foxy/setup.bash
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ros2 topic list -t | grep livox
ros2 topic echo --once /livox/lidar
```

If `rmw_cyclonedds_cpp` is missing on the host:

```bash
sudo apt install ros-foxy-rmw-cyclonedds-cpp
```

### Record LiDAR data

```bash
docker compose run --rm -v .:/log lidar \
  /bin/bash -c "cd /log && /home/devuser/livox_ws/src/run.sh <id> ros2 launch /home/devuser/livox_ws/src/record_MID360_launch.py"
```

## Prerequisites

- Docker (with Compose v2) installed on the host.
- For the camera: a Luxonis DepthAI/OAK USB camera connected to the host.
- For the LiDAR: a Livox sensor connected over Ethernet; host static IP `192.168.1.50` (default). Set `LIVOX_HOST_IP` if your host uses a different IP. Sensor IP defaults to `192.168.1.1<last-two-digits-of-serial>` (e.g. serial ending `50` → sensor IP `192.168.1.150`).
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

### Automated node verification

`verify_nodes.sh` checks that both the camera and LiDAR topics are actively
broadcasting. Run it on the host after starting the containers:

```bash
# One-time: set the host environment to match the containers
export ROS_DOMAIN_ID=0
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
source /opt/ros/$ROS_DISTRO/setup.bash

# Run the verification script
./verify_nodes.sh
```

The script prints `PASS` / `FAIL` for each topic and exits with code `1` if any
node is not broadcasting. You can customise topic names, the timeout, and the
minimum expected rate via environment variables:

| Variable | Default | Description |
|---|---|---|
| `CAMERA_TOPIC` | `/oak/rgb/image_raw` | Camera topic to verify |
| `LIDAR_TOPIC` | `/livox/lidar` | LiDAR topic to verify |
| `VERIFY_TIMEOUT` | `10` | Seconds to wait for each topic |
| `VERIFY_MIN_HZ` | `1.0` | Minimum acceptable publish rate (Hz) |
| `ROS_DISTRO` | `humble` | ROS 2 distribution to source if `ros2` is not on `PATH` |


> **Tip:** To avoid setting these exports in every terminal, add them to your `~/.bashrc`:
> ```bash
> echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc
> echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc
> ```
