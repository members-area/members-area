juice = require 'juice'
htmlToText = require 'html-to-text'

module.exports = (app) ->
  app.sendEmail = (template, locals, done) ->
    return done new Error "No subject specified" unless locals.subject
    return done new Error "No to address specified" unless locals.to
    app.render "emails/#{template}", locals, (err, html) =>
      return done err if err
      options =
        url: process.env.SERVER_ADDRESS
      juice.juiceContent html, options, (err, html) =>
        return done err if err
        mailOptions =
          from: app.emailSetting.meta.settings.from_address ? "members-area@example.com"
          to: locals.to
          subject: locals.subject
          html: html
          text: htmlToText.fromString(html, tables: true)
        app.mailTransport.sendMail mailOptions, done
