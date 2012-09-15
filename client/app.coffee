'use strict'

console.log('extension script loaded with jquery and underscore')

# check when 'compose' view is loaded
window.addEventListener('hashchange', ->
  console.log(window.location.hash)
  payment.renderButton() if window.location.hash.match(/compose/)
)

# all kinds of payment stuffs
payment =
  renderButton : ->
    MAIN_FRAME_SELECTOR = '#canvas_frame'

    # $actions = $('#:di')
    $actions = $(MAIN_FRAME_SELECTOR).contents()
                                     .find('div[role=navigation]')
                                     .last().children().first()

    # append '$' in compose view after email actions
    $actions.append('<div class="J-J5-Ji">$</div>').children('span').remove()

# DOM ready
$(->
  $(window).trigger('hashchange')
)
  
