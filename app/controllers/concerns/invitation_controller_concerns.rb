module InvitationControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :set_invitation

    include InstanceMethods
  end

  module InstanceMethods
    def accept
      user = current_user || @invitation.member
      workshop = @invitation.workshop

      return back_with_message(t('messages.already_rsvped')) if @invitation.attending?

      if user.has_existing_RSVP_on(workshop.date_and_time)
        return back_with_message(t('messages.invitations.rsvped_to_other_workshop'))
      end

      if workshop.attendee?(user) || workshop.waitlisted?(user)
        return back_with_message(t('messages.already_invited'))
      end

      @workshop = WorkshopPresenter.decorate(@invitation.workshop)
      if available_spaces?(@workshop, @invitation)
        @invitation.update(attending: true, note: invitation_note, rsvp_time: Time.zone.now)
        @workshop.send_attending_email(@invitation)

        return back_with_message(t('messages.accepted_invitation', name: @invitation.member.name))
      else
        return back_with_message(t('messages.no_available_seats'))
      end
    end

    def reject
      @workshop = WorkshopPresenter.decorate(@invitation.workshop)
      if @invitation.workshop.date_and_time - 3.5.hours >= Time.zone.now

        if @invitation.attending.eql? false
          redirect_back(fallback_location: invitation_path(@invitation),
                        notice: t('messages.not_attending_already'))
        else
          @invitation.update_attribute(:attending, false)

          next_spot = WaitingList.next_spot(@invitation.workshop, @invitation.role)

          if next_spot.present?
            invitation = next_spot.invitation
            next_spot.destroy
            invitation.update(attending: true, rsvp_time: Time.zone.now, automated_rsvp: true)
            @workshop.send_attending_email(invitation, true)
          end

          redirect_back(fallback_location: invitation_path(@invitation),
                        notice: t('messages.rejected_invitation', name: @invitation.member.name))
        end
      else
        redirect_back(fallback_location: invitation_path(@invitation),
                      notice: 'You can only change your RSVP status up to 3.5 hours before the workshop')
      end
    end


    private

    def invitation_note
      params[:workshop_invitation] ? params[:workshop_invitation][:note] : ''
    end

    def back_with_message(message)
      redirect_back(fallback_location: invitation_path(@invitation), notice: message)
    end
  end
end
