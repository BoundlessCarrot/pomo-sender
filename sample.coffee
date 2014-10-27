{MongoClient} = require 'mongodb'
Sender = require './index'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

mailer = require('pomo-mailer')
  account:
    service: 'Postmark'
    auth:
      user: 'postmark-api-token'
      pass: 'postmark-api-token'

  send_from: 'Pomotodo <robot@pomotodo.com>'

  default_language: 'en_US'
  languages: _.map fs.readdirSync("#{__dirname}/node_modules/pomo-mailer/locale"), (file_name) ->
    return path.basename file_name, '.json'

  template_prefix: "#{__dirname}/node_modules/pomo-mailer/template"
  locale_prefix: "#{__dirname}/node_modules/pomo-mailer/locale"

MongoClient.connect 'mongodb://localhost/test', (err, db) ->
  queue_collection = db.collection 'email_queue'

  sender = new Sender
    category: 'sample'
    mongo: db
    mailer: mailer

  sender.startRunMailQueue()

  queue_collection.insert
    category: 'sample'
    timezone: 'Asia/Shanghai'
    email: 'jysperm@gmail.com'
    language: 'zh_CN'
    view_data:
      id: 'EM42'
  , ->
