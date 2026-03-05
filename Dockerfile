# Dockerfile (ROS2 Foxy minimal pattern)
# Default to ARM64 so this builds on Jetson without qemu/binfmt emulation.
# Override for x86_64 if needed, e.g.:
#   docker build --build-arg ROS_BASE_IMAGE=osrf/ros:foxy-desktop .
ARG ROS_BASE_IMAGE=arm64v8/ros:foxy-ros-base-focal
FROM ${ROS_BASE_IMAGE}

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# 1) Base build tools + camera-node deps + CycloneDDS RMW
#    (mirrors the prerequisites from ece191-ros2-depthai-camera)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions \
    python3-pip \
    python3-yaml \
    build-essential \
    ros-foxy-rclpy \
    ros-foxy-sensor-msgs \
    ros-foxy-cv-bridge \
    ros-foxy-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

# 2) Install DepthAI SDK (not available via rosdep / apt)
RUN pip3 install depthai

# Use CycloneDDS as the RMW for host-container topic visibility
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV ROS_DOMAIN_ID=0

# 3) Create workspace
WORKDIR /ws
RUN mkdir -p src

# 4) Copy your ROS2 packages into src/
#    (adjust path if your repo layout differs)
COPY . /ws/src/

# 5) Resolve package deps (optional but recommended)
RUN apt-get update && rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    rm -rf /var/lib/apt/lists/*

# 6) Build
RUN source /opt/ros/foxy/setup.bash && \
    colcon build --symlink-install

# 7) Container startup: source ROS + workspace, then launch
# CMD ["bash", "-lc", "source /opt/ros/foxy/setup.bash && source /ws/install/setup.bash && ros2 launch <your_package> <your_launch>.launch.py"]
