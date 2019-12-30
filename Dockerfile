# parameters
ARG REPO_NAME="<REPO_NAME_HERE>"

# ==================================================>
# ==> Do not change this code
ARG ARCH=arm32v7
ARG MAJOR=ente
ARG BASE_TAG=${MAJOR}-${ARCH}
ARG BASE_IMAGE=dt-ros-commons

# define base image
FROM duckietown/${BASE_IMAGE}:${BASE_TAG}

# define repository path
ARG REPO_NAME
ARG REPO_PATH="${CATKIN_WS_DIR}/src/${REPO_NAME}"

# create repo directory
RUN mkdir -p "${REPO_PATH}"
WORKDIR "${REPO_PATH}"

# build ROS packages
COPY packages-ros.txt /tmp/packages-ros.txt
RUN \
  set -ex; \
  cd ${ROS_SRC_DIR}; \
  PACKAGES=$(sed -e '/#[ ]*BLACKLIST/,$d' /tmp/packages-ros.txt | sed "/^#/d" | uniq | sed -z "s/\n/ /g"); \
  HAS_PACKAGES=$(echo $PACKAGES | sed '/^\s*#/d;/^\s*$/d' | wc -l); \
  if [ $HAS_PACKAGES -eq 1 ]; then \
    # merge ROS packages into the current workspace
    dt_analyze_packages /tmp/packages-ros.txt; \
    # replace python -> python3 in all the shebangs of the packages
    dt_py2to3; \
    # blacklist packages
    dt_blacklist_packages /tmp/packages-ros.txt; \
    # install dependencies (replacing python -> python3, excluding libboost)
    dt_install_dependencies ./src; \
    # build and clean
    dt_build_ros_packages; \
  fi; \
  set +ex

# install apt dependencies
COPY ./dependencies-apt.txt "${REPO_PATH}/"
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    $(awk -F: '/^[^#]/ { print $1 }' dependencies-apt.txt | uniq) \
  && rm -rf /var/lib/apt/lists/*

# install python dependencies
COPY ./dependencies-py3.txt "${REPO_PATH}/"
RUN pip3 install -r ${REPO_PATH}/dependencies-py3.txt

# copy the source code
COPY . "${REPO_PATH}/"

# build packages
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
  catkin build \
    --workspace ${CATKIN_WS_DIR}/

# define launch script
ENV LAUNCHFILE "${REPO_PATH}/launch.sh"

# define command
CMD ["bash", "-c", "${LAUNCHFILE}"]

# store module name
LABEL org.duckietown.label.module.type "${REPO_NAME}"
ENV DT_MODULE_TYPE "${REPO_NAME}"

# store module metadata
ARG ARCH
ARG MAJOR
ARG BASE_TAG
ARG BASE_IMAGE
LABEL org.duckietown.label.architecture "${ARCH}"
LABEL org.duckietown.label.code.location "${REPO_PATH}"
LABEL org.duckietown.label.code.version.major "${MAJOR}"
LABEL org.duckietown.label.base.image "${BASE_IMAGE}:${BASE_TAG}"
# <== Do not change this code
# <==================================================

# maintainer
LABEL maintainer="<YOUR_FULL_NAME> (<YOUR_EMAIL_ADDRESS>)"
