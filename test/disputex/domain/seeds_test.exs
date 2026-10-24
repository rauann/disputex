defmodule Disputex.Domain.SeedsTest do
  use Disputex.DataCase, async: false

  alias Disputex.Domain
  alias Disputex.Domain.Seeds

  test "plan/0 is deterministic and builds about 200 bookings" do
    assert Seeds.plan() == Seeds.plan()

    plan = Seeds.plan()

    assert length(plan.policies) == 3
    assert length(plan.customers) == 80
    assert length(plan.bookings) == 200
    assert hd(plan.bookings).attrs.ref == "BK-1001"
    assert hd(plan.bookings).attrs.stripe_charge_id == "ch_seed_0001"

    refs = Enum.map(plan.bookings, & &1.attrs.ref)
    charges = Enum.map(plan.bookings, & &1.attrs.stripe_charge_id)
    assert refs == Enum.uniq(refs)
    assert charges == Enum.uniq(charges)
    assert Enum.all?(plan.bookings, &(&1.customer_index in 0..79))
    assert plan.stays != []
    assert plan.emails != []
    assert plan.access_logs != []

    phones = Enum.map(plan.customers, & &1.attrs.phone)

    for prefix <- ["+1 ", "+55 ", "+44 ", "+49 ", "+33 ", "+61 ", "+81 "] do
      assert Enum.any?(phones, &String.starts_with?(&1, prefix))
    end
  end

  test "insert! persists the plan once" do
    assert Domain.empty?()
    assert {:ok, %{bookings: 200, customers: 80}} = Seeds.insert!()
    refute Domain.empty?()
    assert {:ok, :already_seeded} = Seeds.insert!()
  end
end
