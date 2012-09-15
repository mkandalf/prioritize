'use strict'

console.log('Value for Gmail extension script loaded')

# check when 'compose' view is loaded
window.addEventListener 'hashchange', ->
  console.log window.location.hash
  if window.location.hash.match /compose/
    payment.renderButton()

# the iframe that contains the main gmail app
MAIN_FRAME_SELECTOR = '#canvas_frame'

# all kinds of payment stuffs
payment =
  renderButton: ->

    # $actions = $('#:di')
    $actions = $(MAIN_FRAME_SELECTOR).contents()
                                     .find('div[role=navigation]')
                                     .last().children().first()

    # append '$' in compose view after email actions
    $actions.append('<div id="payment-button">$</div>')
            .children('span').remove()

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
  console.log 'loaded'
  inbox.sort()

# DOM ready
$ ->
  $(window).trigger 'hashchange'

