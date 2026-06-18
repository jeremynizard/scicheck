class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale

  private

  # Locale precedence: explicit ?locale= (remembered in the session) → session →
  # Accept-Language header → default. Lets a chosen language stick across the
  # POST/redirect/GET flow without threading the param through every link.
  def switch_locale(&action)
    requested = params[:locale]
    session[:locale] = requested if available_locale?(requested)
    locale = session[:locale] || locale_from_header || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def available_locale?(locale)
    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end

  def locale_from_header
    header = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil if header.blank?

    tag = header.scan(/[a-z]{2}/i).first&.downcase
    tag if available_locale?(tag)
  end
end
