class UserMailer < ActionMailer::Base
  default from: "bookit@chalmers.it"

  def reject_party(booking, mail_params)
    @booking = booking
    @params = mail_params
    mail to: @params[:email], subject: "Din bokning \"#{@booking.title}\" i #{@booking.room} godkändes ej"
  end
end
