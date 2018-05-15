defmodule EWalletAPI.V1.TransactionViewTest do
  use EWalletAPI.ViewCase, :v1
  alias EWalletAPI.V1.TransactionView
  alias EWallet.Web.{Date, V1.MintedTokenSerializer}

  describe "EWalletAPI.V1.TransactionView.render/2" do
    test "renders transaction.json with correct structure" do
      transaction = insert(:transfer)

      expected = %{
        version: @expected_version,
        success: true,
        data: %{
          object: "transaction",
          id: transaction.id,
          idempotency_token: transaction.idempotency_token,
          from: %{
            object: "transaction_source",
            address: transaction.from,
            amount: transaction.from_amount,
            minted_token_id: transaction.from_minted_token.id,
            minted_token: MintedTokenSerializer.serialize(transaction.from_minted_token)
          },
          to: %{
            object: "transaction_source",
            address: transaction.to,
            amount: transaction.to_amount,
            minted_token_id: transaction.to_minted_token.id,
            minted_token: MintedTokenSerializer.serialize(transaction.to_minted_token)
          },
          exchange: %{
            object: "exchange",
            rate: 1
          },
          metadata: %{some: "metadata"},
          encrypted_metadata: %{},
          status: transaction.status,
          created_at: Date.to_iso8601(transaction.inserted_at),
          updated_at: Date.to_iso8601(transaction.updated_at)
        }
      }

      assert render(TransactionView, "transaction.json", transaction: transaction) == expected
    end
  end
end
