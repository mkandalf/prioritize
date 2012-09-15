'use strict'

console.log('Value for Gmail extension script loaded')

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  if window.location.hash.match /compose/
    payment.renderButton()

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'

linkCSS = ($frame) ->
  $frame.contents().find('head').append $('<link/>',
    rel: 'stylesheet'
    type: 'text/css'
    href: chrome.extension.getURL('gmail_canvas.css')
  )

# all kinds of payment stuffs
payment =
  renderButton: ->
    $frame = $(MAIN_FRAME_SELECTOR)
    linkCSS($frame)

    $actions = $frame.contents().find('div[role=navigation]').last()
                     .children().first()

    $actions.children('span').remove()
    # append '$' in compose view after email actions
    # TODO: replace with handlebars template
    $actions.children().last().before(
      '<div id="payment-button">$<input type="text" name="pay_amount" /></div>')

inbox =
  sort: ->
    $emails = $(MAIN_FRAME_SELECTOR).contents().find('table > colgroup')
                                    .eq(1).parent().find('tr')

    emails = _(emails).map (email, i) ->
      subject = email.find('td[role=link] div > span:first-child').text()
      # regex for our payment field format
      value = subject.match /^\$[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{2})?\$/
      if value?
        # strip off leading $ signs
        value = parseFloat value[0][1:-2]
      else
        value = 0
      subject: subject
      value: value
      index: i

    console.log emails

$(MAIN_FRAME_SELECTOR).load ->
  console.log 'main frame loaded'

  if window.location.hash.match /inbox/
    inbox.sort()
  else if window.location.hash.match /compose/
    payment.renderButton()

# DOM ready
$ ->

