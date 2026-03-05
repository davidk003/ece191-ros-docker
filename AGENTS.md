# AGENTS.md

## Cursor Cloud specific instructions

This is a Docker-based ROS 2 robotics project with two containerized sensor nodes (camera and LiDAR). All application logic runs inside Docker containers — there is no host-native application to run.

### Services

| Service | Image | Base ROS distro | What it does |
|---------|-------|-----------------|--------------|
| **camera** | `ece191/camera:foxy` | Foxy (Python 3.8) | Publishes RGB frames from a DepthAI/OAK USB camera |
| **lidar** | `ece191/lidar:humble` | Humble (Python 3.10) | Publishes PointCloud2 + IMU from a Livox MID360 LiDAR |

### Building Docker images

The default `docker-compose.yml` uses ARM64 base images for the camera service. On x86_64 (Cloud VM), override the base image:

- **LiDAR**: `docker compose build lidar` (default `osrf/ros:humble-desktop` is already x86_64)
- **Camera**: The Dockerfile's `pip3 install --upgrade pip setuptools wheel` upgrades setuptools beyond Python 3.8 compatibility (`importlib_metadata.EntryPoints` missing). To build on x86_64, pin setuptools < 71 in the pip install step. A dev-only Dockerfile is needed (see `/tmp/Dockerfile.camera.dev` created during setup) or pass `--build-arg ROS_BASE_IMAGE=ros:foxy-ros-base-focal` and pin setuptools.

### Running smoke tests (no hardware needed)

```bash
# Camera
docker run --rm ece191/camera:foxy bash -c \
  "source /opt/ros/foxy/setup.bash && source /ws/install/setup.bash && \
   ros2 pkg list | grep -q ros2_depthai_package && echo 'PASSED'"

# LiDAR
docker run --rm ece191/lidar:humble bash -c \
  "source /opt/ros/humble/setup.bash && source /home/devuser/livox_ws/install/setup.bash && \
   ros2 pkg list | grep -q livox_ros_driver2 && echo 'PASSED'"
```

### Lint / tests

Run inside the camera container (see `ece191-ros2-depthai-camera/README.md` § Development):

```bash
docker run --rm ece191/camera:foxy bash -c \
  "source /opt/ros/foxy/setup.bash && source /ws/install/setup.bash && \
   cd /ws && colcon test --packages-select ros2_depthai_package && colcon test-result --verbose"
```

Bash scripts can be syntax-checked with `bash -n verify_nodes.sh`.

### Key caveats

- **No physical hardware in Cloud VM**: Both nodes require real sensors (USB camera / Ethernet LiDAR) for full E2E. Without hardware, the camera node starts in reconnect-wait mode, and the LiDAR driver cannot connect to a sensor.
- **Docker daemon must be started**: Run `sudo dockerd &>/tmp/dockerd.log &` and `sudo chmod 666 /var/run/docker.sock` if Docker is not already running.
- **Foxy/Python 3.8 setuptools breakage**: The camera Dockerfile's `pip3 install --upgrade pip setuptools wheel` can break on any architecture when PyPI ships setuptools >= 71. Pin to `setuptools<71` when building locally.
