_ = require 'underscore'
async = require 'async'
moment = require 'moment-timezone'

mailQueue_sample =
  category: 'changes2014.jade'
  timezone: 'Asia/Shanghai'
  email: 'jysperm@gmail.com'
  language: 'zh_CN'
  options: {}
  view_data: {}

module.exports = class Sender
  default_options:
    category: null
    mongo: null
    mailer: null

    queue_collection: 'email_queue'
    log_collection: 'email_log'

    local_time_start: 8
    local_time_end: 16

    logger: console

    sort_order:
      _id: 1

    threads: 5

    send_bucket_size: 100

    retry:
      no_available_timezone: 600 * 1000
      no_more_mail: 600 * 1000

  options: null
  mailQueue: null
  mailLog: null
  logger: null
  mailer: null

  is_running: false

  constructor: (options) ->
    @options = _.extend _.clone(@default_options), options
    @mailQueue = @options.mongo.collection @options.queue_collection
    @mailLog = @options.mongo.collection @options.log_collection
    @logger = @options.logger
    @mailer = @options.mailer

  getTimezones: (callback) =>
    @mailQueue.aggregate [
      $match:
        category: @options.category
    ,
      $group:
        _id: '$timezone'
    ], (err, timezones) ->
      @logger.error err if err
      callback _.pluck timezones, '_id'

  getAvailableTimezones: (timezones) =>
    return _.filter timezones, (timezone) =>
      local_hour = moment().tz(timezone).hour()
      return @options.local_time_end > local_hour >= @options.local_time_start

  stopRunMailQueue: =>
    @is_running = false

  startRunMailQueue: =>
    if @is_running
      return

    @is_running = true

    async.forever (callback) =>
      unless @is_running
        @logger.log '[startRunMailQueue] stop run mail queue'
        return callback true

      @runMailQuere callback
    , ->

  runMailQuere: (callback) =>
    @getTimezones (timezones) =>
      available_timezone = @getAvailableTimezones timezones

      if _.isEmpty available_timezone
        @logger.log '[runMailQuere] no available timezone'
        return setTimeout callback, @options.retry.no_available_timezone

      @mailQueue.find
        category: @options.category
        timezone:
          $in: available_timezone
      ,
        sort: @options.sort_order
        limit: @options.send_bucket_size
      .toArray (err, emails) =>
        if _.isEmpty emails
          @logger.log '[runMailQuere] no more mail can send'
          return setTimeout callback, @options.retry.no_more_mail

        async.eachLimit emails, @options.threads, (email, callback) =>
          @sendMail email, callback
        , ->
          setImmediate callback

  sendMail: (email, callback) =>
    options = _.extend (email.options ? {}),
      language: email.language
      timezone: email.timezone

    @mailer.sendMail @options.category, email.email, email.view_data, options, (err, info) =>
      if err
        @logger.error err
        return callback()

      @logger.log "[sendMail] #{email.email} (#{email.language} @ #{email.timezone})"

      @mailLog.insert _.extend email
        info: info
      , ->
        @mailQueue.remove
          _id: email._id
        , ->
          callback
