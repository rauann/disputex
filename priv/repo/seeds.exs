case Disputex.Domain.Seeds.insert!() do
  {:ok, :already_seeded} ->
    IO.puts("domain already seeded")

  {:ok, summary} ->
    IO.puts("seeded #{summary.bookings} bookings for #{summary.customers} customers")
end
