defmodule EWalletDB.AccountTest do
  use EWalletDB.SchemaCase
  alias EWalletDB.Account
  alias EWalletDB.Helpers.Preloader

  describe "Account factory" do
    test_has_valid_factory(Account)
    test_encrypted_map_field(Account, "account", :encrypted_metadata)
  end

  describe "Account.insert/1" do
    test_insert_generate_uuid(Account, :uuid)
    test_insert_generate_external_id(Account, :id, "acc_")
    test_insert_generate_timestamps(Account)
    test_insert_prevent_blank(Account, :name)
    test_insert_prevent_duplicate(Account, :name)
    test_default_metadata_fields(Account, "account")

    test "inserts a non-master account by default" do
      {:ok, account} = :account |> params_for() |> Account.insert()
      refute Account.master?(account)
    end

    test "inserts and associates categories when provided a list of category_ids" do
      [cat1, cat2] = insert_list(2, :category)

      {:ok, account} =
        :account
        |> params_for()
        |> Map.put(:category_ids, [cat1.id, cat2.id])
        |> Account.insert()

      account = Repo.preload(account, :categories)

      assert Enum.member?(account.categories, cat1)
      assert Enum.member?(account.categories, cat2)
      assert Enum.count(account.categories) == 2
    end

    test "prevents inserting an account without a parent" do
      {res, changeset} =
        :account
        |> params_for(parent: nil)
        |> Account.insert()

      assert res == :error

      assert Enum.member?(
               changeset.errors,
               {:parent_uuid, {"can't be blank", [validation: :required]}}
             )
    end

    test "inserts primary/burn wallets for the account" do
      {:ok, account} = :account |> params_for() |> Account.insert()
      primary = Account.get_primary_wallet(account)
      burn = Account.get_default_burn_wallet(account)

      assert primary != nil
      assert burn != nil
      assert length(account.wallets) == 2
    end

    test "prevents inserting an account beyond 1 child level" do
      account0 = Account.get_master_account()

      {:ok, account1} =
        :account
        |> params_for(%{parent: account0})
        |> Account.insert()

      {res, changeset} =
        :account
        |> params_for(parent: account1)
        |> Account.insert()

      assert res == :error

      assert changeset.errors ==
               [
                 {:parent_uuid,
                  {"is at the maximum child level", [validation: :account_level_limit]}}
               ]
    end
  end

  describe "update/2" do
    test_update_field_ok(Account, :name)
    test_update_field_ok(Account, :description)
  end

  describe "update/2 with category_ids" do
    test "associates the category if it's been added to category_ids" do
      # Prepare 4 categories. We will start of the account with 2, add 1, and leave one behind.
      [cat1, cat2, cat3, _not_used] = insert_list(4, :category)

      {:ok, account} =
        :account
        |> params_for()
        |> Map.put(:category_ids, [cat1.id, cat2.id])
        |> Account.insert()

      # Make sure that the account has 2 categories
      assert_categories(account, [cat1, cat2])

      # Now update with additional category_ids
      {:ok, updated} = Account.update(account, %{category_ids: [cat1.id, cat2.id, cat3.id]})

      # Assert that the 3rd category is added
      assert_categories(updated, [cat1, cat2, cat3])
    end

    test "removes the category if it's no longer in the category_ids" do
      [cat1, cat2] = insert_list(2, :category)

      {:ok, account} =
        :account
        |> params_for()
        |> Map.put(:category_ids, [cat1.id, cat2.id])
        |> Account.insert()

      # Make sure that the account has 2 categories
      assert_categories(account, [cat1, cat2])

      # Now update by removing a category from category_ids
      {:ok, updated} = Account.update(account, %{category_ids: [cat1.id]})

      # Only one category should be left
      assert_categories(updated, [cat1])
    end

    test "removes all categories if category_ids is an empty list" do
      [cat1, cat2] = insert_list(2, :category)

      {:ok, account} =
        :account
        |> params_for()
        |> Map.put(:category_ids, [cat1.id, cat2.id])
        |> Account.insert()

      # Make sure that the account has 2 categories
      assert_categories(account, [cat1, cat2])

      # Now update by removing a category from category_ids
      {:ok, updated} = Account.update(account, %{category_ids: []})

      # No category should be left
      assert_categories(updated, [])
    end

    test "does nothing if category_ids is nil" do
      [cat1, cat2] = insert_list(2, :category)

      {:ok, account} =
        :account
        |> params_for()
        |> Map.put(:category_ids, [cat1.id, cat2.id])
        |> Account.insert()

      # Make sure that the account has 2 categories
      assert_categories(account, [cat1, cat2])

      # Now update by passing a nil category_ids
      {:ok, updated} = Account.update(account, %{category_ids: nil})

      # The categories should remain the same
      assert_categories(updated, [cat1, cat2])
    end

    defp assert_categories(account, expected) do
      account = Repo.preload(account, :categories)

      Enum.each(expected, fn category ->
        assert Enum.member?(account.categories, category)
      end)

      assert Enum.count(account.categories) == Enum.count(expected)
    end
  end

  describe "get/2" do
    test_schema_get_returns_struct_if_given_valid_id(Account)
    test_schema_get_returns_nil_for_id(Account, "not_an_id")
    test_schema_get_returns_nil_for_id(Account, "acc_00000000000000000000000000")
    test_schema_get_accepts_preload(Account, :wallets)
  end

  describe "get_by/2" do
    test_schema_get_by_allows_search_by(Account, :name)
  end

  describe "get_master_account/1" do
    test "returns the master account" do
      result = Account.get_master_account()

      assert result.id == get_or_insert_master_account().id
      assert %Ecto.Association.NotLoaded{} = result.wallets
      assert Account.master?(result)
    end

    test "returns the master account with wallets if preload is given" do
      result = Account.get_master_account(preload: :wallets)

      assert result.id == get_or_insert_master_account().id
      assert Account.master?(result)
    end
  end

  describe "get_primary_wallet/1" do
    test "returns the primary wallet" do
      {:ok, inserted} = :account |> params_for() |> Account.insert()
      wallet = Account.get_primary_wallet(inserted)

      [name: inserted.name]
      |> Account.get_by()
      |> Repo.preload([:wallets])

      assert wallet != nil
      assert wallet.name == "primary"
      assert wallet.identifier == "primary"
    end
  end

  describe "get_default_burn_wallet/1" do
    test "returns the burn wallet" do
      {:ok, inserted} = :account |> params_for() |> Account.insert()
      wallet = Account.get_default_burn_wallet(inserted)

      [name: inserted.name]
      |> Account.get_by()
      |> Repo.preload([:wallets])

      assert wallet != nil
      assert wallet.name == "burn"
      assert wallet.identifier == "burn"
    end
  end

  describe "get_depth/1" do
    test "returns 0 if the given account is the master account" do
      account = Account.get_master_account()
      assert Account.get_depth(account) == 0
    end

    test "returns 1 if the given account is directly below the master account" do
      account0 = Account.get_master_account()
      account1 = insert(:account, %{parent: account0})
      assert Account.get_depth(account1) == 1
    end

    test "returns 3 if the given account is 3 steps below the master account" do
      account0 = Account.get_master_account()
      account1 = insert(:account, %{parent: account0})
      account2 = insert(:account, %{parent: account1})
      account3 = insert(:account, %{parent: account2})
      assert Account.get_depth(account3) == 3
    end
  end

  describe "add_category/2" do
    test "returns an account with the added category" do
      [category1, category2] = insert_list(2, :category)

      account =
        :account
        |> insert(categories: [category1])
        |> Preloader.preload(:categories)

      assert account.categories == [category1]

      {:ok, account} = Account.add_category(account, category2)
      account = Account.get(account.id, preload: :categories)

      assert Enum.member?(account.categories, category1)
      assert Enum.member?(account.categories, category2)
      assert Enum.count(account.categories) == 2
    end
  end
end
