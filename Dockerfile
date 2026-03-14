FROM ruby:3.2.10-slim
ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV RAILS_ENV development
ENV BUNDLE_PATH /usr/local/bundle
ENV PATH /usr/local/bundle/bin:$PATH

RUN apt-get update -qq \
  && apt-get install -y curl gnupg build-essential libpq-dev libvips libvips-dev pkg-config postgresql-client libyaml-dev \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g yarn

WORKDIR /tt_log

COPY Gemfile Gemfile.lock package.json yarn.lock ./

RUN gem install bundler \
  && bundle install \
  && yarn install

COPY . .

RUN gem install foreman

EXPOSE 3000

CMD ["bin/dev"]
