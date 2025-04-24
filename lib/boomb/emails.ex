defmodule Boomb.Emails do
  import Swoosh.Email
  alias Boomb.Mailer

  def confirmation_email(user) do
    confirmation_url = "http://37.27.0.208/confirm?token=#{user.confirmation_token}" # Update for production

    new()
    |> to(user.email)
    |> from({"Boomb Support", "support@boomb.com"})
    |> subject("Confirm Your Boomb Account")
    |> text_body("""
    Hello,

    Thank you for registering with Boomb! Please click the link below to activate your account:

    #{confirmation_url}
    <a href="{confirmation_url}">Click Here to ACTIVATE your account </a>

    If you did not create this account, please ignore this email.

    Regards,
    The Boomb Team
    """)
    |> Mailer.deliver()
  end
end