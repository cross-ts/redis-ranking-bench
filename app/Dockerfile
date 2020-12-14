FROM ruby:latest
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY ./ ./
