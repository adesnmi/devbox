# "Heavily inspired" by https://github.com/microsoft/vscode-dev-containers/blob/v0.192.0/containers/ubuntu/.devcontainer/base.Dockerfile
# Update the VARIANT arg in devcontainer.json to pick an Ubuntu version: focal, bionic
ARG VARIANT="focal"
FROM buildpack-deps:${VARIANT}-curl

# Labels
LABEL org.opencontainers.image.source = "https://github.com/adesnmi/devbox"

# Args
ARG INSTALL_ZSH="true"
ARG UPGRADE_PACKAGES="true"
ARG USERNAME=muyiwa
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ARG NEOVIM_VERSION=stable
ARG NEOVIM_BUILD_DIR=/tmp/nvim-build-${NEOVIM_VERSION}

ARG RUBY_3_VERSION="3.0.3"

ARG DOTFILES_DIR=/home/${USERNAME}/.dotfiles

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
COPY scripts/*.sh scripts/*.env /tmp/scripts/
RUN yes | unminimize 2>&1 \
  && bash /tmp/scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" "true" "true" \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/scripts

# Prefer zsh
RUN chsh -s /usr/bin/zsh ${USERNAME}

# Unix
RUN apt-get update
RUN apt-get -y install software-properties-common
RUN apt-get -y install gawk
RUN apt-get -y install autoconf bison build-essential dirmngr libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev

# Install nvim build deps
RUN sudo apt-get -y install ninja-build gettext libtool libtool-bin automake cmake g++ pkg-config unzip curl doxygen

# Clone repo and build within its context
RUN git clone https://github.com/neovim/neovim ${NEOVIM_BUILD_DIR}
WORKDIR ${NEOVIM_BUILD_DIR}
RUN git checkout ${NEOVIM_VERSION}
RUN make -j4
RUN make install

WORKDIR /home/${USERNAME}

# Docker
RUN apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update
RUN apt-get -y install docker-ce docker-ce-cli containerd.io

# Personal preferences
RUN add-apt-repository -y ppa:aos1/diff-so-fancy
RUN apt-get update -y
RUN apt-get install -y diff-so-fancy

# User changes
USER ${USERNAME}

# Run docker without sudo
RUN sudo usermod -aG docker ${USERNAME}

# Ruby
RUN sudo apt-get -y install rbenv

RUN git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
RUN rbenv install ${RUBY_3_VERSION}
RUN rbenv global ${RUBY_3_VERSION}

# Dotfiles
ADD https://api.github.com/repos/adesnmi/dotfiles/commits?per_page=1 cache_skip
RUN git clone https://github.com/adesnmi/dotfiles ${DOTFILES_DIR}
WORKDIR ${DOTFILES_DIR}
RUN mkdir -p /home/${USERNAME}/.config/nvim
RUN ./install

COPY templates/gitconfig.local.template /home/${USERNAME}/.gitconfig.local

# Initialise Neovim
RUN nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
RUN nvim --headless -c 'quitall'

# Node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | zsh

RUN echo "source $HOME/.nvm/nvm.sh && \
    nvm install 16 && \
    nvm use 16" | zsh

RUN echo "source $HOME/.nvm/nvm.sh && npm install --global yarn" | zsh

# End up back at 🏡
WORKDIR /home/${USERNAME}
