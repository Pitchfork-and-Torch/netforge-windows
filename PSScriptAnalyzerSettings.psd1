@{
    # Driver-specific and optional network tweaks intentionally swallow errors.
    ExcludeRules = @(
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile'
    )
}