# App Store Review Reply — Guideline 2.4.5(i)

Hello App Review Team,

Thank you for your review and for identifying the issue under Guideline 2.4.5(i). We have updated Kairumo so that user-created notebooks and recordings are no longer available only inside the app's hidden sandbox container.

The new build includes the following changes:

1. On Mac, after onboarding, Kairumo presents the standard system folder picker and asks the user to select a user-accessible parent folder. When the user selects Documents (or another folder), Kairumo creates or reuses a clearly named **Kairumo Doc** folder there.
2. The selected folder becomes the app's persistent primary document library. Kairumo uses a security-scoped bookmark so it can continue reading and writing that location after the app is relaunched.
3. Existing notebooks, notebook packages, attachments, and recordings are copied to the selected library before the app switches locations. All subsequent automatic saves, recordings, imports, exports, backups, and synchronization operations use that selected library as their primary source.
4. On iPhone and iPad, the default primary library is **Kairumo Doc** in the app's Documents area, which is available through the Files app. Users can also change the primary library from **Home > Data & Sync > Primary Document Library** using the standard system folder picker.
5. Each device retains its own local folder selection. We do not synchronize absolute local paths between Mac, iPhone, and iPad. Cross-device synchronization continues to identify notebooks by their stable notebook and device identifiers through the configured synchronization provider, including Google Drive. This allows devices with different file-system paths to find and merge the same notebooks correctly.
6. The existing **Save As…** command remains available in the notebook editor and continues to use the standard system export dialog.

Suggested review steps:

1. Launch Kairumo on Mac and complete onboarding.
2. In the folder picker, select the user's Documents folder.
3. Confirm that a **Kairumo Doc** folder is created and is visible in Finder.
4. Create or edit a notebook and make a recording, then confirm that the corresponding library data is updated in that folder.
5. To change the location again, open **Home > Data & Sync > Primary Document Library** and select another user-accessible folder.
6. To verify cross-device behavior, sign in to the same Google Drive synchronization account on another Apple device and open the app; the device uses its own selected local library while synchronizing the same notebook identities and content.

We believe these changes address Guideline 2.4.5(i) by giving users control over a standard, user-accessible document location and by continuously using that location as the primary source for their content.

Thank you for your consideration.

Sincerely,  
The Kairumo Team
