import React, { Component, useEffect } from "react";
import { Dialog, DialogTitle, DialogContent, IconButton, Typography } from '@material-ui/core';
import { Grid, Table, TableBody, TableCell, TableFooter, TableHead, TableRow, TablePagination } from '@material-ui/core';
import CloseIcon from '@material-ui/icons/Close';


function Entry(props) {
	const { open, onClose, entry } = props;
	const handleClose = () => {
    onClose();
  };

  let players = entry.players.reduce((res, player) => {
  	player.position == 'CPT' ? res.unshift(player) : res.push(player)
  	return res
  }, []);

	return (
    <Dialog onClose={handleClose} aria-labelledby='contest-summary' open={open} PaperProps={{style: {margin: '8px'}}}>
      <DialogTitle id='entry-title' disableTypography={true}>
      	<Grid container>
		    	<Grid item xs={7}><Typography variant="subtitle2">{entry.username}'s Entry</Typography></Grid>
		    	<Grid item xs={3} style={{color: 'green'}}>
		    		<Typography variant="subtitle2" align="center">
		    			${Number(entry.winning).toLocaleString()}
		    		</Typography>
		    	</Grid>
		    	<Grid item xs={2} align="right">
		    		<IconButton aria-label="close" onClick={handleClose} style={{padding: 0, marginTop: '-3px'}}>
		          <CloseIcon />
		        </IconButton>
		    	</Grid>
      	</Grid>
    	</DialogTitle>
      <DialogContent dividers>
      	<Grid container>
      		<Grid item xs={12}>
      			<Table aria-label="payouts">
			        <TableHead>
			          <TableRow>
			          	<TableCell>Name</TableCell>
			            <TableCell>Position</TableCell>
			            <TableCell>Points</TableCell>
			          </TableRow>
			        </TableHead>
			        <TableBody>
			          {players.map((row, i) => (
			            <TableRow key={i}>
			              <TableCell component="th" scope="row">{row.name}</TableCell>
			              <TableCell>{row.position}</TableCell>
			              <TableCell>{row.points}</TableCell>
			            </TableRow>
			          ))}
			          <TableRow key={entry.players.length + 1}>
			          	<TableCell colSpan={2} style={{borderBottom: 'none'}}></TableCell>
			          	<TableCell style={{borderBottom: 'none'}}><Typography variant="subtitle1">{entry.points}</Typography></TableCell>
			          </TableRow>
			        </TableBody>
			      </Table>
      		</Grid>
      	</Grid>
      </DialogContent>
    </Dialog>
  );
}

export default function EntriesTable(props) {
	const { entries, entryPage, onChangePage } = props
	const [selectedEntry, setSelectedEntry] = React.useState(null);
	const [open, setOpen] = React.useState(false);

	const handleEntryClick = (entry) => {
    setSelectedEntry(entry);
  };

  const handleClose = () => {
    setOpen(false);
  };

  useEffect(() => {
  	if(selectedEntry) {
  		setOpen(true);
  	}
  }, [selectedEntry]);

	return (
		<React.Fragment>
			<Table aria-label="simple table">
		    <TableHead>
		      <TableRow>
		        <TableCell>Username</TableCell>
		        <TableCell>Points</TableCell>
		        <TableCell>Winning&nbsp;($)</TableCell>
		      </TableRow>
		    </TableHead>
		    <TableBody>
		      {entries.map((row, i) => (
		        <TableRow key={i} hover={true} onClick={() => handleEntryClick(row)} style={{cursor: 'pointer'}}>
		          <TableCell component="th" scope="row">
		            {row.username}
		          </TableCell>
		          <TableCell>{row.points}</TableCell>
		          <TableCell>${Number(row.winning).toLocaleString()}</TableCell>
		        </TableRow>
		      ))}
		    </TableBody>
		  </Table>
		  <TablePagination
		    component="div"
		    count={1000}
		    rowsPerPage={10}
		    rowsPerPageOptions={[]}
		    page={entryPage}
		    onChangePage={(event, page) => onChangePage(page)}
		  />
		  {selectedEntry && <Entry open={open} onClose={handleClose} entry={selectedEntry} />}
		</React.Fragment>
	)
}