FROM amazonlinux:2

ENV TZ=Asia/Kolkata
ENV ROOT_PATH=/builder-hub
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN amazon-linux-extras install -y postgresql13
RUN yum install -y postgresql-devel

RUN yum install -y htop nc tar gzip git procps
RUN yum install -y https://s3.ap-south-1.amazonaws.com/hypto-installers/wkhtmltox.rpm
RUN yum install -y libpng12 zlib-devel gcc-c++ make

RUN curl -sL https://rpm.nodesource.com/setup_16.x | bash
RUN yum install -y nodejs
RUN npm install --global yarn
RUN npm install --global ts-node
RUN npm install --global aws-cdk
RUN yum install -y jq
RUN yum install -y unzip
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

RUN amazon-linux-extras install -y ruby3.0
RUN yum install -y ruby-devel redhat-rpm-config

RUN gem install bundler -v 2.2.31

RUN mkdir $ROOT_PATH
WORKDIR $ROOT_PATH
ADD . $ROOT_PATH
COPY ./.aws /root/.aws

RUN bundle install
RUN bundle exec rails webpacker:install

CMD $ROOT_PATH/run.sh
