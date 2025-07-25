RSpec.describe "Partners profile edit", type: :system, js: true do
  let!(:partner1) { create(:partner, status: "invited") }
  let(:partner1_user) { partner1.primary_user }

  context "step-wise editing is enabled" do
    before do
      Flipper.enable(:partner_step_form)
      login_as(partner1_user)
      visit edit_partners_profile_path
    end

    it "displays all sections in a closed state by default" do
      within ".accordion" do
        expect(page).to have_css("#agency_information.accordion-collapse.collapse", visible: false)
        expect(page).to have_css("#program_delivery_address.accordion-collapse.collapse", visible: false)

        partner1.partials_to_show.each do |partial|
          expect(page).to have_css("##{partial}.accordion-collapse.collapse", visible: false)
        end

        expect(page).to have_css("#partner_settings.accordion-collapse.collapse", visible: false)
      end
    end

    it "allows sections to be opened, closed, filled in any order, and submit for approval" do
      # Media
      find("button[data-bs-target='#media_information']").click
      expect(page).to have_css("#media_information.accordion-collapse.collapse.show", visible: true)
      within "#media_information" do
        fill_in "Website", with: "https://www.example.com"
      end
      find("button[data-bs-target='#media_information']").click
      expect(page).to have_css("#media_information.accordion-collapse.collapse", visible: false)

      # Executive director
      find("button[data-bs-target='#executive_director']").click
      expect(page).to have_css("#executive_director.accordion-collapse.collapse.show", visible: true)
      within "#executive_director" do
        fill_in "Executive Director Name", with: "Lisa Smith"
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Submit and Review
      all("input[type='submit'][value='Save and Review']").last.click
      expect(current_path).to eq(partners_profile_path)
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")
    end

    it "displays the edit view with sections containing validation errors expanded" do
      # Open up Media section and clear out website value
      find("button[data-bs-target='#media_information']").click
      within "#media_information" do
        fill_in "Website", with: ""
        uncheck "No Social Media Presence"
      end

      # Open Pick up person section and fill in 4 email addresses
      find("button[data-bs-target='#pick_up_person']").click
      within "#pick_up_person" do
        fill_in "Pick Up Person's Email", with: "email1@example.com, email2@example.com, email3@example.com, email4@example.com"
      end

      # Open Partner Settings section and uncheck all options
      find("button[data-bs-target='#partner_settings']").click
      within "#partner_settings" do
        uncheck "Enable Quantity-based Requests" if has_checked_field?("Enable Quantity-based Requests")
        uncheck "Enable Child-based Requests (unclick if you only do bulk requests)" if has_checked_field?("Enable Child-based Requests (unclick if you only do bulk requests)")
        uncheck "Enable Requests for Individuals" if has_checked_field?("Enable Requests for Individuals")
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click

      # Expect an alert-danger message containing validation errors
      expect(page).to have_css(".alert-danger", text: /There is a problem/)
      expect(page).to have_content("No social media presence must be checked if you have not provided any of Website, Twitter, Facebook, or Instagram.")
      expect(page).to have_content("Enable child based requests At least one request type must be set")
      expect(page).to have_content("Pick up email can't have more than three email addresses")

      # Expect media section, executive director section, and partner settings section to be opened
      expect(page).to have_css("#media_information.accordion-collapse.collapse.show", visible: true)
      expect(page).to have_css("#pick_up_person.accordion-collapse.collapse.show", visible: true)
      expect(page).to have_css("#partner_settings.accordion-collapse.collapse.show", visible: true)

      # Try to Submit and Review from error state
      all("input[type='submit'][value='Save and Review']").last.click

      # Expect an alert-danger message containing validation errors
      expect(page).to have_css(".alert-danger", text: /There is a problem/)
      expect(page).to have_content("No social media presence must be checked if you have not provided any of Website, Twitter, Facebook, or Instagram.")
      expect(page).to have_content("Enable child based requests At least one request type must be set")
      expect(page).to have_content("Pick up email can't have more than three email addresses")

      # Expect media section, executive director section, and partner settings section to be opened
      expect(page).to have_css("#media_information.accordion-collapse.collapse.show", visible: true)
      expect(page).to have_css("#pick_up_person.accordion-collapse.collapse.show", visible: true)
      expect(page).to have_css("#partner_settings.accordion-collapse.collapse.show", visible: true)
    end

    it "preserves previously uploaded documents when adding new attachments" do
      # Open attached documents section
      find("button[data-bs-target='#attached_documents']").click
      expect(page).to have_css("#attached_documents.accordion-collapse.collapse.show", visible: true)

      # Upload the first document
      within "#attached_documents" do
        attach_file("partner_profile_documents", Rails.root.join("spec/fixtures/files/document1.md"), make_visible: true)
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Verify the document is listed
      visit edit_partners_profile_path
      find("button[data-bs-target='#attached_documents']").click
      within "#attached_documents" do
        expect(page).to have_link("document1.md")
      end

      # Upload a second document
      within "#attached_documents" do
        attach_file("partner_profile_documents", Rails.root.join("spec/fixtures/files/document2.md"), make_visible: true)
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Verify both documents are listed
      visit edit_partners_profile_path
      find("button[data-bs-target='#attached_documents']").click
      within "#attached_documents" do
        expect(page).to have_link("document1.md")
        expect(page).to have_link("document2.md")
      end
    end

    it "allows removal of attached documents" do
      # Open attached documents section
      find("button[data-bs-target='#attached_documents']").click
      expect(page).to have_css("#attached_documents.accordion-collapse.collapse.show", visible: true)

      # Upload multiple documents at once
      within "#attached_documents" do
        attach_file("partner_profile_documents", [
          Rails.root.join("spec/fixtures/files/document1.md"),
          Rails.root.join("spec/fixtures/files/document2.md")
        ], make_visible: true)

        # Verify both documents are displayed in custom selection list
        expect(page).to have_text("Selected files:")
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document1.md")
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document2.md")
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Verify both documents persist after page reload
      visit edit_partners_profile_path
      find("button[data-bs-target='#attached_documents']").click
      within "#attached_documents" do
        expect(page).to have_link("document1.md")
        expect(page).to have_link("document2.md")
      end

      # Remove the first document
      within "#attached_documents" do
        document_name = "document1.md"
        document_li = find("li.attached-document", text: document_name)
        document_li.find("a.btn-danger", text: "Remove").click
        expect(page).not_to have_selector("li.attached-document", text: document_name)
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Verify only one document remains
      visit edit_partners_profile_path
      find("button[data-bs-target='#attached_documents']").click
      within "#attached_documents" do
        expect(page).to have_link("document2.md")
        expect(page).not_to have_link("document1.md")
      end
    end

    it "persists individual file upload when there are validation errors" do
      # Open up Agency Information section and upload proof-of-status letter
      find("button[data-bs-target='#agency_information']").click
      within "#agency_information" do
        expect(find("label[for='partner_profile_proof_of_partner_status']")).to have_content("Choose file...")
        attach_file("partner_profile_proof_of_partner_status", Rails.root.join("spec/fixtures/files/irs_determination_letter.md"), make_visible: true)
        expect(find("label[for='partner_profile_proof_of_partner_status']")).to have_content("irs_determination_letter.md")
      end

      # Open Pick up person section and fill in 4 email addresses which will generate a validation error
      find("button[data-bs-target='#pick_up_person']").click
      within "#pick_up_person" do
        fill_in "Pick Up Person's Email", with: "email1@example.com, email2@example.com, email3@example.com, email4@example.com"
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click

      # Expect an alert-danger message containing validation errors
      expect(page).to have_css(".alert-danger", text: /There is a problem/)

      # Open up Agency Information section and expect the file field to remember users selection
      # but NOT be persisted because there hasn't yet been a successful form submission.
      find("button[data-bs-target='#agency_information']").click
      within "#agency_information" do
        expect(find("label[for='partner_profile_proof_of_partner_status']")).to have_content("irs_determination_letter.md")
        expect(page).not_to have_content("Attached file:")
        expect(page).not_to have_link("irs_determination_letter.md")
      end

      # Fix validation error in Pick up person section: It's already open due to having a validation error
      within "#pick_up_person" do
        fill_in "Pick Up Person's Email", with: "email1@example.com, email2@example.com, email3@example.com"
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Open up Agency Information section and expect file is persisted
      find("button[data-bs-target='#agency_information']").click
      within "#agency_information" do
        expect(page).to have_content("Attached file:")
        expect(page).to have_link("irs_determination_letter.md", href: /\/rails\/active_storage\/blobs\/redirect\/.+\/irs_determination_letter\.md/)
        expect(find("label[for='partner_profile_proof_of_partner_status']")).to have_content("irs_determination_letter.md")
      end
    end

    it "persists multiple file uploads when there are validation errors" do
      # Open Pick up person section and fill in 4 email addresses which will generate a validation error
      find("button[data-bs-target='#pick_up_person']").click
      within "#pick_up_person" do
        fill_in "Pick Up Person's Email", with: "email1@example.com, email2@example.com, email3@example.com, email4@example.com"
      end

      # Open attached documents section
      find("button[data-bs-target='#attached_documents']").click
      expect(page).to have_css("#attached_documents.accordion-collapse.collapse.show", visible: true)

      # Upload multiple documents
      within "#attached_documents" do
        attach_file("partner_profile_documents", [
          Rails.root.join("spec/fixtures/files/document1.md"),
          Rails.root.join("spec/fixtures/files/document2.md")
        ], make_visible: true)

        # Verify both documents are displayed in custom selection list
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document1.md")
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document2.md")
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click

      # Expect an alert-danger message containing validation errors
      expect(page).to have_css(".alert-danger", text: /There is a problem/)

      # Open attached documents section
      find("button[data-bs-target='#attached_documents']").click
      expect(page).to have_css("#attached_documents.accordion-collapse.collapse.show", visible: true)

      # Expect both documents are still displayed in custom list as selected, but nothing is actually attached
      within "#attached_documents" do
        expect(page).to have_text("Selected files:")
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document1.md")
        expect(page).to have_css("[data-file-input-target='list'] li", text: "document2.md")

        expect(page).not_to have_text("Attached files:")
        expect(page).not_to have_link("document1.md")
        expect(page).not_to have_link("document2.md")
      end

      # Fix validation error in Pick up person section: It's already open due to having a validation error
      within "#pick_up_person" do
        fill_in "Pick Up Person's Email", with: "email1@example.com, email2@example.com, email3@example.com"
      end

      # Save Progress
      all("input[type='submit'][value='Save Progress']").last.click
      expect(page).to have_css(".alert-success", text: "Details were successfully updated.")

      # Open attached documents section
      find("button[data-bs-target='#attached_documents']").click
      expect(page).to have_css("#attached_documents.accordion-collapse.collapse.show", visible: true)

      # Expect both documents are now rendered as downloadable links
      # i.e. they've been saved, without user having had to select them again
      within "#attached_documents" do
        expect(page).to have_text("Attached files:")
        expect(page).to have_link("document1.md")
        expect(page).to have_link("document2.md")
      end
    end
  end
end
