# Dockerfile (ROS2 Foxy minimal pattern)
# Default to ARM64 so this builds on Jetson without qemu/binfmt emulation.
# Override for x86_64 if needed, e.g.:
#   docker build --build-arg ROS_BASE_IMAGE=osrf/ros:foxy-desktop .
ARG ROS_BASE_IMAGE=arm64v8/ros:foxy-ros-base-focal
FROM ${ROS_BASE_IMAGE}

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# 1) Base build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 2) Create workspace
WORKDIR /ws
RUN mkdir -p src

# 3) Copy your ROS2 packages into src/
#    (adjust path if your repo layout differs)
COPY . /ws/src/

# 4) Resolve package deps (optional but recommended)
RUN apt-get update && rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    rm -rf /var/lib/apt/lists/*

# 5) Build
RUN source /opt/ros/foxy/setup.bash && \
    colcon build --symlink-install

# 6) Container startup: source ROS + workspace, then launch
# CMD ["bash", "-lc", "source /opt/ros/foxy/setup.bash && source /ws/install/setup.bash && ros2 launch <your_package> <your_launch>.launch.py"]
