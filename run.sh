#!/usr/bin/env bash
set -euo pipefail

source /opt/ros/"$ROS_DISTRO"/setup.bash
colcon build --packages-select ros2_depthai_package
source install/setup.bash
ros2 run ros2_depthai_package camera_publisher
