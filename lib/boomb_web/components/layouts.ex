defmodule BoombWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BoombWeb, :controller` and
  `use BoombWeb, :live_view`.
  """
  use BoombWeb, :html

  embed_templates "layouts/*"
end
