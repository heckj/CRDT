FROM swift:5.6.2-focal

# Install SPM build dependencies
RUN apt-get update && apt-get install -y curl git make unzip \
    sqlite3 libsqlite3-dev

# Install front-end dependencies
# RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
# RUN apt-get install -y nodejs
# RUN npm install --global yarn

RUN apt-get update && apt-get install -y zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
RUN curl https://raw.githubusercontent.com/heckj/dotfiles/master/zshrc > ~/.zshrc
RUN chsh -s $(which zsh)
RUN cd /tmp
RUN git clone https://github.com/nicklockwood/SwiftFormat ~/.swiftformat
# RUN cd ~/.swiftformat
# RUN ls -altr
# RUN swift build -c release
