FROM ruby:2.6-alpine

RUN apk add --no-cache build-base sqlite-dev nodejs tzdata yarn

WORKDIR /app
COPY Gemfile* .ruby-version /app/
RUN gem install bundler && \
    bundle config --global jobs `nproc` && \
    bundle install

COPY package.json yarn.lock /app/
RUN yarn install --check-files

COPY *.js *.json *.ru *.md Rakefile .browserslistrc .gitignore /app/
COPY app /app/app/
COPY bin /app/bin/
COPY config /app/config/
COPY db /app/db/
COPY lib /app/lib/
COPY public/*.* /app/public/
COPY vendor /vendor/

EXPOSE 3000
CMD ["bin/rails", "s", "-p", "3000", "-b", "0.0.0.0"]
