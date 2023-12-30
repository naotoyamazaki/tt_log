FROM ruby:3.2.2-slim
ENV LANG C.UTF-8
ENV TZ Asia/Tokyo
ENV RAILS_ENV production
ENV BUNDLE_DEPLOYMENT 1
ENV BUNDLE_PATH /usr/local/bundle
ENV BUNDLE_WITHOUT development:test

RUN apt-get update -qq \
&& apt-get install -y curl wget gnupg build-essential libpq-dev nodejs yarn libvips libvips-dev pkg-config postgresql-client \
&& curl -sL https://deb.nodesource.com/setup_16.x | bash - \
&& wget --quiet -O - /tmp/pubkey.gpg https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
&& apt-get update -qq \
&& apt-get install -y nodejs yarn

RUN mkdir /tt_log
WORKDIR /tt_log

COPY Gemfile /tt_log/Gemfile
COPY Gemfile.lock /tt_log/Gemfile.lock
COPY yarn.lock /tt_log/yarn.lock

RUN gem install bundler:2.4.10 \
&& bundle install \
&& yarn install

COPY . /tt_log

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

RUN useradd rails --create-home --shell /bin/bash \
&& chown -R rails:rails /tt_log

RUN gem install foreman

USER rails:rails

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
