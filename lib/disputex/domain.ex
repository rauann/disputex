defmodule Disputex.Domain do
  @moduledoc """
  The fake hotel-booking domain the agent will read in later milestones.
  """

  alias Disputex.Domain.Booking
  alias Disputex.Repo

  @doc "True when no bookings have been seeded."
  @spec empty?() :: boolean()
  def empty? do
    Repo.aggregate(Booking, :count) == 0
  end
end
