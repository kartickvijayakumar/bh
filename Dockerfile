FROM ruby:3.0.2-alpine AS run-env

ENV TZ=Asia/Kolkata
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#ARG PACKAGES="tzdata nodejs jq"
ARG ROOT_PATH=/bh
ARG BUILD_PACKAGES="build-base curl-dev git"
ARG DEV_PACKAGES="postgresql-dev yaml-dev zlib-dev nodejs yarn"
ARG RUBY_PACKAGES="tzdata"
ARG OTHER_PACKAGES="curl npm postgresql-client bash unzip jq"

RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $OTHER_PACKAGES

RUN npm install --global yarn
RUN npm install --global ts-node

RUN npm install --global aws-cdk
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

RUN mkdir $ROOT_PATH
WORKDIR $ROOT_PATH
ADD . $ROOT_PATH

RUN gem install bundler -v 2.2.31
RUN bundle install
RUN bundle exec rails webpacker:install
RUN bundle exec rake assets:precompile

EXPOSE 80
CMD ./run.sh
